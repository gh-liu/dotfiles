import { describe, expect, test, vi } from "vitest";
import { renderSubagentCall, renderSubagentCompletion, renderSubagentResult } from "./index.ts";

const theme = {
  fg: (_color: string, value: string) => value,
  bg: (_color: string, value: string) => value,
  bold: (value: string) => value,
  getThinkingBorderColor: (_level: string) => (value: string) => value,
} as never;
const text = (component: { render(width: number): string[] }) => component.render(200).join("\n").trim();

const runContext = (state: Record<string, unknown> = {}) => ({
  args: { action: "run", agent: "scout", task: "Inspect auth" },
  isError: false,
  state,
  invalidate: vi.fn(),
} as never);

describe("task API rendering", () => {
  test("renders durable invocation records without transient status", () => {
    const call = text(renderSubagentCall({ action: "run", agent: "scout", task: "Inspect auth", background: true }, theme));
    expect(call).toBe("scout — Inspect auth");
    expect(call).not.toContain("running");
    expect(call).not.toContain("tracking");
    expect(text(renderSubagentCall({ action: "get", ref: "2", waitMs: 30_000 }, theme))).toContain("get · #2 · wait 30s");
    expect(text(renderSubagentCall({ action: "cancel", ref: "#2" }, theme))).toContain("cancel · #2");
    expect(text(renderSubagentCall({ action: "close", ref: "#2" }, theme))).toContain("close · #2");
  });

  test("shows the full provider, model, and thinking level without expanding", () => {
    const rendered = text(renderSubagentCall({
      action: "run", agent: "worker", model: "opencode-go/deepseek-v4-flash", thinking: "minimal", task: "Implement auth",
    }, theme));
    expect(rendered).toContain("worker · opencode-go/deepseek-v4-flash · minimal — Implement auth");
    expect(rendered).not.toContain("thinking minimal");
    const coloredTheme = {
      ...theme,
      getThinkingBorderColor: (level: string) => (value: string) => `<thinking-${level}>${value}</thinking-${level}>`,
    } as never;
    expect(text(renderSubagentCall({
      action: "run", agent: "worker", model: "vendor/model", thinking: "minimal", task: "Implement auth",
    }, coloredTheme))).toContain("<thinking-minimal>minimal</thinking-minimal>");
  });

  test("retains a useful multi-line prompt budget in the invocation record", () => {
    const task = "Inspect the authentication lifecycle from middleware registration through token refresh, identify concurrency risks, and cite the exact implementation and test files that support every conclusion.";
    const rendered = text(renderSubagentCall({ action: "run", agent: "scout", task }, theme));
    const normalized = rendered.replace(/\s+/g, " ");
    expect(normalized).toContain("middleware registration through token refresh");
    expect(normalized).toContain("support every conclusion");
  });

  test("expanded invocation shows the bounded task", () => {
    const args = {
      action: "run" as const,
      agent: "worker",
      task: "Implement cache invalidation in src/cache.ts. Keep the API stable and run the focused tests.",
    };
    const rendered = text(renderSubagentCall(args, theme, { args, expanded: true, isError: false, state: {}, invalidate: vi.fn() } as never));
    for (const expected of ["Task", "Implement cache invalidation", "src/cache.ts", "Keep the API stable"]) {
      expect(rendered).toContain(expected);
    }
  });

  test("renders a followup on the same session", () => {
    const args = { action: "followup" as const, ref: "#2", agent: "scout", task: "Now compare the tests with the implementation." };
    const call = text(renderSubagentCall(args, theme, { args, expanded: true, isError: false, state: { turn: 2 }, invalidate: vi.fn() } as never));
    expect(call).toContain("↳ #2 scout · turn 2");
    expect(call).toContain("Now compare the tests");
  });

  test("renders input errors as errors rather than unknown sessions", () => {
    const rendered = text(renderSubagentResult(
      { content: [], details: { error: "task is required for subagent run" } },
      { expanded: true, isPartial: false },
      theme,
      { ...runContext(), isError: true } as never,
    ));
    expect(rendered).toContain("✗ subagent error");
    expect(rendered).toContain("task is required for subagent run");
    expect(rendered).not.toContain("unknown session");
    expect(rendered).not.toContain("Summary");
  });

  test("partial tool results show the complete sanitized foreground activity", () => {
    const context = runContext();
    const details = {
      status: "running",
      activity: "read a.ts…",
      phase: { kind: "thinking", status: "running" },
      timeline: [{ kind: "tool", id: "a", summary: "read a.ts", status: "completed" }],
      toolProgress: { earlierCount: 2, history: [], active: [{ id: "b", summary: "test auth.ts" }] },
    };
    const rendered = text(renderSubagentResult({ content: [{ type: "text", text: "Thinking…" }], details }, { expanded: true, isPartial: true }, theme, context));
    expect(rendered).toContain("● running");
    expect(rendered).not.toContain("● running ·");
    expect(rendered.match(/read a\.ts/g)).toHaveLength(1);
    expect(rendered).not.toContain("Timeline");
    expect(rendered).toContain("✓ read a.ts");
    expect(rendered).toContain("… 2 earlier tool activities");
    expect(rendered).toContain("◷ test auth.ts");
    expect(rendered).not.toContain("Thinking…");
    expect(rendered).not.toContain("private reasoning");
    expect(rendered).not.toContain("id: b");
    const coloredTheme = { ...theme, fg: (color: string, value: string) => `<${color}>${value}</${color}>` } as never;
    const colored = text(renderSubagentResult({ content: [], details }, { expanded: true, isPartial: true }, coloredTheme, context));
    expect(colored).toContain("<syntaxFunction>read</syntaxFunction><muted> a.ts</muted>");
    expect(colored).toContain("<syntaxFunction>test</syntaxFunction><muted> auth.ts</muted>");
    const partitionedTheme = {
      ...coloredTheme,
      bg: (color: string, value: string) => `<${color}>${value}</${color}>`,
    } as never;
    const partitioned = text(renderSubagentResult({ content: [], details }, { expanded: true, isPartial: true }, partitionedTheme, context));
    expect(partitioned).toContain("<toolPendingBg>");
    const [statusLine, ...activityLines] = partitioned.split("\n");
    expect(statusLine).not.toContain("<success>✓</success>");
    expect(activityLines.join("\n")).toContain("<success>✓</success> <syntaxFunction>read</syntaxFunction>");
    const collapsed = text(renderSubagentResult({ content: [], details }, { expanded: false, isPartial: true }, theme, context));
    expect(collapsed).toContain("● running");
    expect(collapsed).not.toContain("● running ·");
    expect(collapsed).toContain("✓ read a.ts");
    expect((context as { state: { spinnerTimer?: unknown } }).state.spinnerTimer).toBeUndefined();
  });

  test("renders terminal foreground and recovered background handoffs", () => {
    const foreground = text(renderSubagentResult({ content: [], details: { ref: "#1", agent: "scout", turn: 1, status: "idle", turnStatus: "completed", summary: "Done", elapsedMs: 1_000 } }, { expanded: false, isPartial: false }, theme, runContext()));
    expect(foreground).toContain("✓ #1 scout · turn 1 · 1s");
    expect(foreground).toContain("Done");
    expect(foreground).toContain("#1 · workstream open · follow up gaps or close when accepted");
    const runExpanded = text(renderSubagentResult({ content: [], details: {
      ref: "#1",
      agent: "scout",
      status: "idle",
      turnStatus: "completed",
      summary: "Done",
      timeline: [
        { kind: "tool", id: "a", summary: "read auth.ts", status: "completed" },
        { kind: "thinking", text: "private reasoning" },
      ],
    } }, { expanded: true, isPartial: false }, theme, runContext()));
    expect(runExpanded).not.toContain("Timeline");
    expect(runExpanded).toContain("✓ read auth.ts");
    expect(runExpanded).not.toContain("private reasoning");

    const recovered = text(renderSubagentResult({
      content: [], details: { ref: "#2", agent: "scout", status: "idle", turnStatus: "completed", summary: "Recovered background result", elapsedMs: 2_000 },
    }, { expanded: false, isPartial: false }, theme, {
      args: { action: "get", ref: "#2" }, isError: false, state: {}, invalidate: vi.fn(),
    } as never));
    expect(recovered).toContain("✓ #2 scout · 2s");
    expect(recovered).toContain("Recovered background result");
  });

  test("renders get diagnostics and cancel semantics", () => {
    const getContext = { args: { action: "get", ref: "#2" }, isError: false, state: {}, invalidate: vi.fn() } as never;
    const expanded = text(renderSubagentResult({ content: [], details: {
      status: "running", activity: "reading auth.ts", recentActivity: ["Thinking", "completed: grep auth"],
      timeline: [
        { kind: "tool", id: "a", summary: "read auth.ts", status: "completed" },
        { kind: "thinking", text: "private reasoning" },
        { kind: "tool", id: "b", summary: "npm test", status: "failed" },
      ],
    } }, { expanded: true, isPartial: false }, theme, getContext));
    expect(expanded).toContain("Current");
    expect(expanded).not.toContain("Timeline");
    expect(expanded).toContain("✓ read auth.ts");
    expect(expanded).toContain("✗ npm test");
    expect(expanded).toContain("Thinking");
    expect(expanded).not.toContain("private reasoning");
    const collapsed = text(renderSubagentResult({ content: [], details: {
      status: "running", timeline: [{ kind: "tool", id: "a", summary: "read auth.ts", status: "completed" }],
    } }, { expanded: false, isPartial: false }, theme, getContext));
    expect(collapsed).not.toContain("Timeline");

    const cancel = text(renderSubagentResult({ content: [], details: { ref: "#2", status: "interrupted", cancelled: true } }, { expanded: false, isPartial: false }, theme, {
      args: { action: "cancel", ref: "#2" }, isError: false, state: {}, invalidate: vi.fn(),
    } as never));
    expect(cancel).toContain("cancel acknowledged");

    const close = text(renderSubagentResult({ content: [], details: {
      ref: "#2", agent: "scout", status: "closed", closed: true,
    } }, { expanded: false, isPartial: false }, theme, {
      args: { action: "close", ref: "#2" }, isError: false, state: {}, invalidate: vi.fn(),
    } as never));
    expect(close).toContain("✓ #2 scout · workstream closed");
  });

  test("hydrates every run title with the authoritative short ref", async () => {
    const env = (await import("../test/harness.ts")).setup();
    const tool = env.extension.getTool();
    const state: Record<string, unknown> = {};
    const invalidate = vi.fn();
    tool.renderResult!({ content: [], details: { ref: "#7", status: "starting", model: "vendor/model", thinking: "high" } } as never, { expanded: false, isPartial: true }, theme, {
      args: { action: "run", agent: "scout", task: "Inspect", background: false }, isError: false, state, invalidate,
    } as never);
    await Promise.resolve();
    const rendered = text(tool.renderCall!({ action: "run", agent: "scout", task: "Inspect", background: false } as never, theme, { args: {}, isError: false, state, invalidate } as never));
    expect(rendered).toContain("#7 scout · vendor/model · high — Inspect");
    expect(rendered).not.toContain("tracking");
    await env.extension.shutdown();
  }, 20_000);

  test("renders result-first completion cards without status backgrounds", () => {
    const taggedTheme = { ...theme, bg: (color: string, value: string) => `<${color}>${value}</${color}>` } as never;
    const completed = {
      jobId: "job-1", operationId: "operation-1", turn: 1, ref: "#1", agent: "scout", task: "Inspect auth", status: "completed" as const, sessionOpen: true as const,
      summary: "Mapped the auth lifecycle.", evidence: "src/auth.ts", validation: "tests pass", elapsedMs: 2_000,
    };
    const collapsed = text(renderSubagentCompletion({ content: "", details: completed }, { expanded: false, outputPad: 0 }, taggedTheme));
    expect(collapsed).toContain("✓ scout · turn 1 · 2s");
    expect(collapsed).toContain("Mapped the auth lifecycle.");
    expect(collapsed).toContain("#1 · workstream open · follow up gaps or close when accepted · expand for details");
    expect(collapsed).not.toContain("· completed");

    const expanded = text(renderSubagentCompletion({ content: "", details: completed }, { expanded: true, outputPad: 0 }, taggedTheme));
    expect(expanded).toContain("Task");
    expect(expanded).toContain("Inspect auth");
    expect(expanded).toContain("Evidence");
    expect(expanded).toContain("Validation");
    expect(expanded).toContain("#1");

    const mixed = text(renderSubagentCompletion({ content: "", details: { batch: [
      completed,
      { ...completed, jobId: "job-2", operationId: "operation-2", ref: "#2", status: "failed" as const },
    ] } }, { expanded: false, outputPad: 0 }, taggedTheme));
    expect(mixed).toContain("✗ scout · turn 1 · failed · 2s");
    expect(mixed).not.toContain("<toolPendingBg>");
    expect(mixed).not.toContain("<toolErrorBg>");
    expect(mixed).not.toContain("<toolSuccessBg>");
  });

  test("shows reuse affordances only for genuinely open sessions", () => {
    const unavailable = {
      jobId: "job", operationId: "operation", ref: "#3", agent: "reviewer", task: "Review",
      status: "failed" as const, summary: "Controller crashed.",
    };
    const card = text(renderSubagentCompletion({ content: "", details: unavailable }, { expanded: false, outputPad: 0 }, theme));
    expect(card).toContain("#3 · workstream unavailable");
    expect(card).not.toContain("workstream open");

    const crashed = text(renderSubagentResult({
      content: [], details: { ref: "#3", agent: "reviewer", status: "crashed", error: "Controller crashed." },
    }, { expanded: false, isPartial: false }, theme, {
      args: { action: "get", ref: "#3" }, isError: true, state: {}, invalidate: vi.fn(),
    } as never));
    expect(crashed).not.toContain("workstream open");
  });
});
