import { afterEach, describe, expect, test } from "vitest";
import { chmodSync, existsSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { createRpcSubagentExecutor } from "./rpc-executor.ts";
import { SubagentCancellationError } from "./protocol.ts";
import type { SubagentExecutionProfile, SubagentRunOptions, SubagentWorkOrder } from "./protocol.ts";

const temporaryDirectories: string[] = [];
afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) rmSync(directory, { recursive: true, force: true });
});

function temporaryScript(source: string): string {
  const directory = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-"));
  temporaryDirectories.push(directory);
  const script = join(directory, "fake-pi.mjs");
  writeFileSync(script, source);
  chmodSync(script, 0o755);
  return script;
}

function workOrder(goal: string): SubagentWorkOrder {
  return {
    goal,
    scope: [process.cwd()],
    constraints: [],
    knownDecisions: [],
    evidence: [],
    validation: [],
    returnFormat: "Return findings.",
    projectGuidance: [],
  };
}

function profile(): SubagentExecutionProfile {
  return { name: "scout", systemPrompt: "Inspect files.", tools: ["read"] };
}

function options(script: string, sessionRoot: string, overrides: Partial<SubagentRunOptions> = {}): SubagentRunOptions & {
  command: string;
  commandArgsPrefix: string[];
  sessionRoot: string;
} {
  return {
    cwd: process.cwd(),
    agent: profile(),
    workOrder: workOrder("Inspect the fixture"),
    runId: "run-rpc",
    operationId: "operation-rpc",
    parentSessionId: "parent-rpc",
    deadlineMs: 5_000,
    ...overrides,
    command: process.execPath,
    commandArgsPrefix: [script],
    sessionRoot,
  };
}

describe("one-shot RPC executor", () => {
  test("performs the state/prompt handshake and returns the session reference", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
import { writeFileSync } from "node:fs";
let input = "";
const sessionDir = process.argv[process.argv.indexOf("--session-dir") + 1];
const sessionFile = sessionDir + "/session.jsonl";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") {
      writeFileSync(sessionFile, "fake transcript\\n");
      emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-rpc-1", sessionFile } });
    } else if (command.type === "prompt") {
      emit({ type: "response", id: command.id, command: "prompt", success: true });
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: JSON.stringify({ goal: command.message }) }], stopReason: "stop" } });
      emit({ type: "agent_settled" });
    }
  }
});
`);

    const result = await createRpcSubagentExecutor({ command: process.execPath, commandArgsPrefix: [script], sessionRoot })(options(script, sessionRoot));

    expect(result.status).toBe("completed");
    expect(result.processInstanceId).toMatch(/^[0-9a-f-]{36}$/);
    const summary = JSON.parse(result.summary);
    const delegatedWorkOrder = JSON.parse(summary.goal.split("\n\n", 2)[1]);
    expect(delegatedWorkOrder.goal).toBe("Inspect the fixture");
    expect(result.transcript.sessionId).toBe("session-rpc-1");
    expect(result.transcript.sessionPath).toBe(join(readdirSync(sessionRoot).map((name) => join(sessionRoot, name))[0], "session.jsonl"));
    expect(existsSync(result.transcript.sessionPath!)).toBe(true);
  });

  test("fails when the final assistant message is not a normal stop", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-failed", sessionFile: process.argv[process.argv.indexOf("--session-dir") + 1] + "/session.jsonl" } });
    if (command.type === "prompt") {
      emit({ type: "response", id: command.id, command: "prompt", success: true });
      emit({ type: "message_end", message: { role: "assistant", content: [{ type: "text", text: "partial" }], stopReason: "length" } });
      emit({ type: "agent_settled" });
    }
  }
});
`);

    const result = await createRpcSubagentExecutor({ command: process.execPath, commandArgsPrefix: [script], sessionRoot })(options(script, sessionRoot));
    expect(result.status).toBe("failed");
    expect(result.summary).toBe("partial");
    expect(result.transcript.sessionId).toBe("session-failed");
    expect(result.transcript.sessionPath).toContain("session.jsonl");
  });

  test("cancels and cleans up the owned process group", async () => {
    const sessionRoot = mkdtempSync(join(tmpdir(), "pi-subagent-rpc-root-"));
    temporaryDirectories.push(sessionRoot);
    const script = temporaryScript(`
let input = "";
function emit(value) { process.stdout.write(JSON.stringify(value) + "\\n"); }
process.stdin.on("data", (chunk) => {
  input += chunk;
  let newline;
  while ((newline = input.indexOf("\\n")) !== -1) {
    const command = JSON.parse(input.slice(0, newline));
    input = input.slice(newline + 1);
    if (command.type === "get_state") emit({ type: "response", id: command.id, command: "get_state", success: true, data: { sessionId: "session-cancelled", sessionFile: "/tmp/session-cancelled.jsonl" } });
    if (command.type === "prompt") emit({ type: "response", id: command.id, command: "prompt", success: true });
  }
});
setInterval(() => {}, 1000);
`);
    const controller = new AbortController();
    const running = createRpcSubagentExecutor({ command: process.execPath, commandArgsPrefix: [script], sessionRoot, terminationGraceMs: 25 })(options(script, sessionRoot, { signal: controller.signal }));
    setTimeout(() => controller.abort(), 25);
    await expect(running).rejects.toBeInstanceOf(SubagentCancellationError);
  });
});
