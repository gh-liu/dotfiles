import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { afterAll, expect, test } from "vitest";

import { createRpcSubagentController } from "./rpc-executor.ts";
import type { SubagentRunOptions, SubagentWorkOrder } from "./protocol.ts";

const enabled = process.env.PI_SUBAGENT_LIVE_TEST === "1"
  && typeof process.env.DEEPSEEK_API_KEY === "string"
  && process.env.DEEPSEEK_API_KEY.length > 0;
const temporaryDirectories: string[] = [];

afterAll(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function workOrder(goal: string): SubagentWorkOrder {
  return {
    goal,
    scope: [process.cwd()],
    constraints: ["Do not call tools.", "Reply with only the requested marker."],
    knownDecisions: [],
    evidence: [],
    validation: [],
    returnFormat: "Return only the requested marker.",
    projectGuidance: [],
  };
}

test.runIf(enabled)("runs real Pi with DeepSeek, steers active work, and reuses its session", async () => {
  const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-live-"));
  temporaryDirectories.push(sessionRoot);
  const first: SubagentRunOptions = {
    cwd: process.cwd(),
    agent: {
      name: "live-smoke",
      systemPrompt: "Follow the work order exactly. Be terse and never call tools.",
      model: "deepseek/deepseek-v4-flash",
      thinking: "minimal",
      tools: ["read"],
    },
    workOrder: workOrder("Return exactly LIVE_INITIAL."),
    runId: "live-run",
    operationId: "live-initial",
    parentSessionId: "live-parent",
    deadlineMs: 45_000,
  };
  const controller = await createRpcSubagentController(first, {
    sessionRoot,
    piAgentDirectory: join(process.env.HOME!, ".pi", "agent"),
    authEnvAllowlist: ["DEEPSEEK_API_KEY"],
    terminationGraceMs: 5_000,
  });

  try {
    const initial = controller.start(first);
    await initial.accepted;
    expect(await controller.steer(first.operationId, "Return exactly LIVE_STEERED.")).toBe(true);
    const steered = await initial.result;
    expect(steered).toMatchObject({ status: "completed", operationId: "live-initial" });
    expect(steered.summary).toContain("LIVE_STEERED");

    const followUp = await controller.submit({
      ...first,
      operationId: "live-follow-up",
      workOrder: workOrder("Return exactly LIVE_FOLLOW_UP."),
    });
    expect(followUp).toMatchObject({ status: "completed", operationId: "live-follow-up" });
    expect(followUp.summary).toContain("LIVE_FOLLOW_UP");
    expect(followUp.processInstanceId).toBe(steered.processInstanceId);
    expect(followUp.transcript.sessionId).toBe(steered.transcript.sessionId);
    expect(followUp.transcript.sessionPath).toBe(steered.transcript.sessionPath);
    expect(existsSync(followUp.transcript.sessionPath!)).toBe(true);
  } finally {
    await controller.close();
  }
}, 60_000);
