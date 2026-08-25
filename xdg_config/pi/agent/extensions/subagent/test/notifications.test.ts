import { describe, expect, test, vi } from "vitest";
import { mkdirSync, realpathSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import {
  buildWakeWordSnippet,
  loadSubagentOverrides,
  SUBAGENT_COMPLETION_MESSAGE,
  registerSubagentExtension,
  validateAuthEnvAllowlist,
  temporaryDirectory,
  writeAgent,
  deferred,
  FakeController,
  fakeFactory,
  harness,
  context,
  setup,
  startIdle,
} from "./harness.ts";

describe("subagent notifications", () => {
  test("notifies the parent with compact structured and follow-up titles", async () => {
    const runId = "11111111-1111-4111-8111-111111111111";
    const operationId = "22222222-2222-4222-8222-222222222222";
    const task = [
      "# Delegated work",
      "Outcome: Inspect the subagent runtime lifecycle",
      "Scope: xdg_config/pi/agent/extensions/subagent",
      "Starting evidence: the old wake included the full work order.",
    ].join("\n");
    const env = setup({ ids: [runId, operationId, "follow-up", "interrupted"] });
    const started = await env.invoke({ action: "start", agent: "scout", task });
    env.fake.controllers[0].settle(0, "completed", "Located auth.\nWith supporting evidence.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0]).toMatchObject({
      message: {
        customType: SUBAGENT_COMPLETION_MESSAGE,
        display: true,
        content: expect.stringMatching(
          /^#1 scout · completed · \d+s — Inspect the subagent runtime lifecycle\n  idle · status\/follow-up\/close #1$/,
        ),
        details: {
          runId,
          operationId,
          agent: "scout",
          task,
          status: "completed",
          summary: "Located auth.\nWith supporting evidence.",
          runtimeStatus: "idle",
        },
      },
      options: { triggerTurn: true, deliverAs: "followUp" },
    });
    const wakeContent = env.extension.messages[0].message.content as string;
    expect(wakeContent.split("\n")).toHaveLength(2);
    expect(wakeContent).not.toContain("Outcome:");
    expect(wakeContent).not.toContain("Scope:");
    expect(wakeContent).not.toContain("Starting evidence:");
    expect(wakeContent).not.toContain(runId);
    expect(wakeContent).not.toContain(operationId);
    expect(wakeContent).not.toContain("Located auth.");

    const follow = await env.invoke({
      action: "send",
      id: (started.details as { runId: string }).runId,
      mode: "follow_up",
      message: "  Check   tests  \nScope: not part of the title",
    });
    env.fake.controllers[0].settle(1, "failed", "No complete final response.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(2));
    expect(env.extension.messages[1].message).toMatchObject({
      content: expect.stringMatching(
        /^#1 scout · failed · \d+s — Check tests\n  idle · status\/follow-up\/close #1$/,
      ),
      details: { operationId: (follow.details as { operationId: string }).operationId, status: "failed" },
    });

    const next = await env.invoke({ action: "send", id: runId, mode: "follow_up", message: "Wait" });
    await env.invoke({
      action: "interrupt",
      id: runId,
      expectedOperationId: (next.details as { operationId: string }).operationId,
    });
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(3));
    expect(env.extension.messages[2].message).toMatchObject({
      content: expect.stringMatching(
        /^#1 scout · interrupted · \d+s — Wait\n  idle · status\/follow-up\/close #1$/,
      ),
      details: { status: "interrupted" },
    });

    const renderer = env.extension.messageRenderers.get(SUBAGENT_COMPLETION_MESSAGE)!;
    const completionMessage = {
      role: "custom" as const,
      timestamp: Date.now(),
      ...(env.extension.messages[0].message as never),
    };
    const collapsed = renderer(
      completionMessage,
      { expanded: false, outputPad: 0 },
      { fg: (_color: string, text: string) => text, bold: (text: string) => text, bg: (_color: string, text: string) => text } as never,
    )!.render(240).map((line) => line.trimEnd()).join("\n");
    expect(collapsed).toMatch(/✓ completed · scout \(#1\) · \d+s · Inspect the subagent runtime lifecycle/);
    expect(collapsed).not.toContain("Outcome:");
    expect(collapsed).not.toContain("Scope:");

    const rendered = renderer(
      completionMessage,
      { expanded: true, outputPad: 0 },
      { fg: (_color: string, text: string) => text, bold: (text: string) => text, bg: (_color: string, text: string) => text } as never,
    )!.render(240).map((line) => line.trimEnd()).join("\n");
    expect(rendered).toContain("✓ completed · scout (#1)");
    expect(rendered).toContain("task: Inspect the subagent runtime lifecycle");
    expect(rendered).not.toContain("Outcome:");
    expect(rendered).not.toContain("Scope:");
    expect(rendered).toContain("Located auth.\n  With supporting evidence.");
    expect(rendered).toMatch(/  runtime idle · \d+s/);
    expect(rendered).not.toContain(runId);
    expect(rendered).not.toContain(operationId);
  });

  test("omits the completion title when the task has no meaningful non-heading line", async () => {
    const env = setup();
    await env.invoke({ action: "start", agent: "scout", task: "\n# Work order\n   " });
    env.fake.controllers[0].settle(0, "completed", "Done.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));

    const wakeContent = env.extension.messages[0].message.content as string;
    expect(wakeContent).toMatch(/^#1 scout · completed · \d+s\n  idle · status\/follow-up\/close #1$/);
    expect(wakeContent).not.toContain("—");
    expect(wakeContent.split("\n")).toHaveLength(2);
  });

  test("batches background settlements into one card when the last one finishes", async () => {
    const env = setup({ ids: ["bg-a", "op-a", "bg-b", "op-b"] });
    await env.invoke({ action: "start", agent: "scout", task: "First" });
    await env.invoke({ action: "start", agent: "scout", task: "Second" });

    env.fake.controllers[0].settle(0, "completed", "Alpha report.");
    expect(env.extension.messages).toHaveLength(0); // sibling still running: stay silent

    env.fake.controllers[1].settle(0, "completed", "Beta report.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    const payload = env.extension.messages[0].message.details as { batch?: unknown[] };
    expect(payload.batch).toHaveLength(2);
    const blocks = (env.extension.messages[0].message.content as string).split("\n\n");
    expect(blocks).toHaveLength(3);
    expect(blocks[0]).toBe("2 background subagents settled:");
    expect(blocks[1]).toMatch(/^#1 scout · completed · \d+s — First\n  idle · status\/follow-up\/close #1$/);
    expect(blocks[2]).toMatch(/^#2 scout · completed · \d+s — Second\n  idle · status\/follow-up\/close #2$/);
  });

  test("failures notify immediately while successful siblings stay pending", async () => {
    const env = setup({ ids: ["bg-a", "op-a", "bg-b", "op-b"] });
    await env.invoke({ action: "start", agent: "scout", task: "First" });
    await env.invoke({ action: "start", agent: "scout", task: "Second" });

    env.fake.controllers[1].settle(0, "failed", "Boom.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0].message.details).toMatchObject({ status: "failed" });

    env.fake.controllers[0].settle(0, "completed", "Alpha.");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(2));
    expect(env.extension.messages[1].message.details).toMatchObject({ status: "completed" });
  });

  test("does not notify for one-shot runs or operations settled by close and shutdown", async () => {
    const runEnv = setup();
    const run = runEnv.invoke({ action: "run", agent: "scout", task: "Once" });
    await vi.waitFor(() => expect(runEnv.fake.controllers[0]?.starts).toHaveLength(1));
    runEnv.fake.controllers[0].settle();
    await run;
    expect(runEnv.extension.messages).toEqual([]);

    const closeEnv = setup();
    const active = await closeEnv.invoke({ action: "start", agent: "scout", task: "Wait" });
    await closeEnv.invoke({ action: "close", id: (active.details as { runId: string }).runId });
    await Promise.resolve();
    expect(closeEnv.extension.messages).toEqual([]);

    const shutdownEnv = setup();
    await shutdownEnv.invoke({ action: "start", agent: "scout", task: "Wait" });
    await shutdownEnv.extension.shutdown();
    await Promise.resolve();
    expect(shutdownEnv.extension.messages).toEqual([]);
  });

  test("an accepted active controller crash sends one failed notification", async () => {
    const env = setup();
    const started = await env.invoke({ action: "start", agent: "scout", task: "Crash" });
    env.fake.controllers[0].fail(new Error("Process exited"));
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0].message).toMatchObject({
      details: {
        runId: (started.details as { runId: string }).runId,
        status: "failed",
        summary: "Controller closed",
        runtimeStatus: "crashed",
      },
    });
    await Promise.resolve();
    expect(env.extension.messages).toHaveLength(1);
  });

  test("notification delivery failure cannot change operation state", async () => {
    const env = setup();
    vi.spyOn(env.extension.pi, "sendMessage").mockImplementation(() => { throw new Error("UI unavailable"); });
    const started = await env.invoke({ action: "start", agent: "scout", task: "Finish" });
    const identity = started.details as { runId: string; operationId: string };
    env.fake.controllers[0].settle();
    const waited = await env.invoke({ action: "wait", id: identity.runId, operationId: identity.operationId });
    expect(waited.details).toMatchObject({ status: "completed" });
    expect((await env.invoke({ action: "status", id: identity.runId })).details).toMatchObject({ status: "idle" });
  });

});
