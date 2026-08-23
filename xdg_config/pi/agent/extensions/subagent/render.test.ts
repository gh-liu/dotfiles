import { describe, expect, test, vi } from "vitest";

import {
  renderSubagentCall,
  renderSubagentCompletion,
  renderSubagentResult,
} from "./render.ts";

const theme = {
  fg: (_color: string, text: string) => text,
  bg: (_color: string, text: string) => text,
  bold: (text: string) => text,
} as never;

function rendered(component: { render(width: number): string[] }): string {
  return component.render(240).map((line) => line.trimEnd()).join("\n").trimEnd();
}

function call(args: Record<string, unknown>, expanded = true): string {
  return rendered(renderSubagentCall(args as never, theme, {
    args,
    expanded,
    isError: false,
    state: {},
    invalidate: vi.fn(),
  } as never));
}

function result(
  args: Record<string, unknown>,
  details: Record<string, unknown>,
  options: { expanded?: boolean; isError?: boolean; text?: string } = {},
): string {
  return rendered(renderSubagentResult(
    { content: options.text ? [{ type: "text", text: options.text }] : [], details },
    { expanded: options.expanded ?? false, isPartial: false },
    theme,
    {
      args,
      expanded: options.expanded ?? false,
      isError: options.isError ?? false,
      state: {},
      invalidate: vi.fn(),
    } as never,
  ));
}

describe("subagent render state matrix", () => {
  test.each([
    ["list", { action: "list" }, "refresh agents"],
    ["run", { action: "run", agent: "scout", task: "Outcome: inspect files", deadlineMs: 60_000 }, "scout — inspect files"],
    ["start", { action: "start", agent: "scout", task: "Inspect files", deadlineMs: 60_000 }, "scout · bg — Inspect files"],
    ["status all", { action: "status" }, "status · all runtimes"],
    ["status one", { action: "status", id: "#2" }, "status · #2"],
    ["follow-up", { action: "send", id: "#2", mode: "follow_up", message: "Check tests", deadlineMs: 30_000 }, "follow-up · #2 · 30s\n  Check tests"],
    ["steer", { action: "send", id: "#2", mode: "steer", message: "Focus", expectedOperationId: "op" }, "steer · #2\n  Focus"],
    ["wait all", { action: "wait" }, "wait · all bg"],
    ["wait one", { action: "wait", id: "#2", operationId: "op" }, "wait · #2"],
    ["interrupt", { action: "interrupt", id: "#2", expectedOperationId: "op" }, "interrupt · #2"],
    ["close", { action: "close", id: "#2" }, "close · #2"],
  ])("renders the %s call", (_label, args, expected) => {
    expect(call(args as Record<string, unknown>)).toContain(expected);
  });

  test("keeps status and close collapsed rows silent while expanded rows remain inspectable", () => {
    expect(call({ action: "status", id: "#2" }, false)).toBe("");
    expect(call({ action: "close", id: "#2" }, false)).toBe("");
    expect(call({ action: "status", id: "#2" }, true)).toContain("status · #2");
    expect(call({ action: "close", id: "#2" }, true)).toContain("close · #2");
  });

  test("renders and stops the partial spinner with authoritative countdown and progress", () => {
    const args = { action: "run", agent: "scout", task: "Inspect", deadlineMs: 60_000 };
    const state: Record<string, unknown> = {};
    const context = { args, isError: false, state, invalidate: vi.fn() } as never;
    const partial = rendered(renderSubagentResult(
      { content: [{ type: "text", text: "grep done · working…" }], details: { status: "running", startedAt: Date.now() - 5_000 } },
      { expanded: false, isPartial: true }, theme, context,
    ));
    expect(partial).toMatch(/^⠋ 5\ds — grep done · working…$/);
    expect(state.spinnerTimer).toBeDefined();
    renderSubagentResult(
      { content: [], details: { status: "completed" } },
      { expanded: false, isPartial: false }, theme, context,
    );
    expect(state.spinnerTimer).toBeUndefined();
  });

  test.each([
    ["completed", { action: "run" }, { status: "completed", summary: "Done", elapsedMs: 4_000 }, {}, "✓ completed · 4s\nDone"],
    ["interrupted", { action: "run" }, { status: "interrupted", summary: "Stopped" }, {}, "■ Interrupted — Stopped"],
    ["tool error", { action: "run" }, { status: "failed", error: "No auth" }, { isError: true }, "✗ Failed — No auth"],
    ["list", { action: "list" }, {}, { text: "scout\nworker" }, "Registered agents\nscout\nworker"],
    ["close", { action: "close" }, { status: "closed" }, { expanded: true }, "✓ Closed"],
    ["start", { action: "start" }, { status: "running" }, {}, "↗ started"],
    ["wait timeout", { action: "wait" }, { reason: "timeout", snapshot: { status: "running" } }, {}, "◷ still running"],
    ["interrupt accepted", { action: "interrupt" }, { accepted: true, status: "running" }, {}, "■ Interrupt requested"],
    ["interrupt conflict", { action: "interrupt" }, { accepted: false, status: "idle" }, {}, "• Already idle"],
    ["steer accepted", { action: "send", mode: "steer" }, { accepted: true, status: "running" }, {}, "↪ Steering sent"],
    ["steer rejected", { action: "send", mode: "steer" }, { accepted: false, status: "idle" }, {}, "• Steering not applied"],
    ["running", { action: "status" }, { status: "running", activeOperation: { task: "Inspect tests" } }, {}, "● running · Inspect tests"],
    ["idle", { action: "status" }, { status: "idle" }, {}, "○ idle"],
    ["failed", { action: "status" }, { status: "failed", error: "Provider failed" }, {}, "✗ failed — Provider failed"],
    ["crashed", { action: "status" }, { status: "crashed", error: "Session crashed" }, {}, "✗ crashed — Session crashed"],
    ["cancelled", { action: "status" }, { status: "cancelled", error: "Parent cancelled" }, {}, "✗ cancelled — Parent cancelled"],
    ["closed", { action: "status" }, { status: "closed" }, { expanded: true }, "• closed"],
  ])("renders the %s result branch", (_label, args, details, options, expected) => {
    expect(result(args as Record<string, unknown>, details as Record<string, unknown>, options)).toContain(expected);
  });

  test("renders expanded task, transcript, and bounded multiline output", () => {
    const output = result(
      { action: "run" },
      {
        status: "completed",
        task: "Inspect the lifecycle",
        summary: "Evidence\n- runtime.ts\nValidation\n- tests passed",
        transcript: { sessionPath: `${process.env.HOME}/.pi/subagent-sessions/run/session.jsonl` },
      },
      { expanded: true },
    );
    expect(output).toContain("transcript ~/.pi/subagent-sessions/run/session.jsonl");
    expect(output).toContain("task: Inspect the lifecycle");
    expect(output).toContain("Evidence\n- runtime.ts\nValidation\n- tests passed");
  });

  test.each(["completed", "failed", "interrupted"])("renders collapsed and expanded %s completion cards", (status) => {
    const details = {
      index: 2,
      runId: "run",
      operationId: "operation",
      agent: "scout",
      task: "Inspect lifecycle",
      status,
      summary: "Evidence\nValidation",
      runtimeStatus: "idle",
      elapsedMs: 4_000,
    };
    const collapsed = rendered(renderSubagentCompletion(
      { content: "", details: details as never }, { expanded: false, outputPad: 0 }, theme,
    ));
    const expanded = rendered(renderSubagentCompletion(
      { content: "", details: details as never }, { expanded: true, outputPad: 0 }, theme,
    ));
    expect(collapsed).toContain(`${status} · scout (#2) · Inspect lifecycle`);
    expect(expanded).toContain("task: Inspect lifecycle");
    expect(expanded).toContain("Evidence\n  Validation");
    expect(expanded).toContain("runtime idle · 4s");
  });

  test("renders every entry in a mixed completion batch", () => {
    const entry = (agent: string, status: "completed" | "failed" | "interrupted") => ({
      runId: agent,
      operationId: `${agent}-operation`,
      agent,
      task: `${agent} task`,
      status,
      summary: `${agent} summary`,
      runtimeStatus: "idle" as const,
    });
    const output = rendered(renderSubagentCompletion({ content: "", details: { batch: [
      entry("scout", "completed"),
      entry("researcher", "failed"),
      entry("reviewer", "interrupted"),
    ] } }, { expanded: false, outputPad: 0 }, theme));
    expect(output).toContain("completed · scout");
    expect(output).toContain("failed · researcher");
    expect(output).toContain("interrupted · reviewer");
    expect(output.match(/─/g)).toHaveLength(2);
  });
});
