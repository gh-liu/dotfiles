import { describe, expect, test, vi } from "vitest";
import { renderSubagentCall, renderSubagentCompletion, renderSubagentResult } from "./index.ts";

const theme = { fg: (_color: string, text: string) => text, bg: (_color: string, text: string) => text, bold: (text: string) => text } as never;
const text = (component: { render(width: number): string[] }) => component.render(200).join("\n").trim();

describe("task API rendering", () => {
  test("renders all public calls", () => {
    expect(text(renderSubagentCall({ action: "run", agent: "scout", objective: "Inspect", background: true }, theme))).toContain("scout — Inspect · tracking in Subagents");
    expect(text(renderSubagentCall({ action: "get", jobId: "job-1" }, theme))).toContain("get · resolving job…");
    expect(text(renderSubagentCall({ action: "cancel", jobId: "job-1" }, theme))).toContain("cancel · resolving job…");
    expect(text(renderSubagentCall({ action: "get", jobId: "2", waitMs: 30_000 }, theme))).toContain("get · #2 · wait 30s");
  });

  test("expanded run shows the bounded delegation spec", () => {
    const args = {
      action: "run" as const, agent: "worker", objective: "Implement cache invalidation", scope: ["src/cache.ts"],
      context: "TTL is authoritative", constraints: ["No API changes"], acceptance: ["Tests pass"], deadlineMs: 120_000,
    };
    const rendered = text(renderSubagentCall(args, theme, { args, expanded: true, isError: false, state: {}, invalidate: vi.fn() } as never));
    for (const expected of ["Outcome", "Implement cache invalidation", "Scope", "src/cache.ts", "Context", "TTL is authoritative", "Constraints", "No API changes", "Acceptance", "Tests pass"]) {
      expect(rendered).toContain(expected);
    }
  });

  test("renders progress and terminal handoff", () => {
    const context = { args: { action: "run", agent: "scout", objective: "Inspect", deadlineMs: 60_000 }, isError: false, state: {}, invalidate: vi.fn() } as never;
    expect(text(renderSubagentResult({ content: [{ type: "text", text: "working" }], details: { status: "running" } }, { expanded: false, isPartial: true }, theme, context))).toContain("working");
    const rendered = text(renderSubagentResult({ content: [], details: { status: "completed", summary: "Done", elapsedMs: 1_000 } }, { expanded: false, isPartial: false }, theme, context));
    expect(rendered).toContain("✓ completed · 1s");
    expect(rendered).toContain("Done");
    expect((context as { state: { spinnerTimer?: unknown } }).state.spinnerTimer).toBeUndefined();
  });

  test("renders the nested handoff returned by get", () => {
    const context = { args: { action: "get", jobId: "#2" }, isError: false, state: {}, invalidate: vi.fn() } as never;
    const rendered = text(renderSubagentResult({
      content: [],
      details: { status: "completed", handoff: { summary: "Recovered background result" }, elapsedMs: 2_000 },
    }, { expanded: false, isPartial: false }, theme, context));
    expect(rendered).toContain("✓ completed · 2s");
    expect(rendered).toContain("Recovered background result");
  });

  test("renders interleaved thinking timeline only in partial views", () => {
    const timeline = [
      { kind: "tool", id: "a", summary: "read a.ts", status: "completed" },
      { kind: "thinking", text: "we should inspect the schema first." },
      { kind: "tool", id: "b", summary: "grep schema src", status: "completed" },
    ];
    const context = { args: { action: "run", agent: "scout", objective: "Inspect" }, isError: false, state: {}, invalidate: vi.fn() } as never;
    const partial = text(renderSubagentResult({
      content: [
        { type: "text", text: "working" },
      ],
      details: {
        status: "running",
        timeline,
        toolProgress: { active: [{ id: "c", summary: "bash npm test", status: "running" }] },
      },
    }, { expanded: true, isPartial: true }, theme, context));
    expect(partial).toContain("✓ read a.ts");
    // Thinking only enters the timeline once the executor flushes it (before a
    // tool call), so it is already ended here: completed marker, never a spinner.
    // The raw reasoning text still never reaches the UI.
    expect(partial).toContain("✓ Thinking");
    expect(partial).not.toContain("Thinking…");
    expect(partial).not.toContain("we should inspect the schema first.");
    expect(partial).toContain("✓ grep schema src");
    // Thinking must sit between the two tool calls, not after everything.
    expect(partial.indexOf("✓ read a.ts") < partial.indexOf("✓ Thinking")).toBe(true);
    expect(partial.indexOf("✓ Thinking") < partial.indexOf("✓ grep schema src")).toBe(true);
    // The active call row stays last, after every timeline entry.
    expect(partial.indexOf("✓ grep schema src") < partial.indexOf("⠋ bash npm test…")).toBe(true);
    expect(partial.endsWith("⠋ bash npm test…")).toBe(true);

    const finalContext = { args: context.args, isError: false, state: {}, invalidate: vi.fn() } as never;
    const final = text(renderSubagentResult({
      content: [],
      details: { status: "completed", summary: "Done", timeline },
    }, { expanded: false, isPartial: false }, theme, finalContext));
    expect(final).toContain("✓ completed");
    expect(final).not.toContain("✓ Thinking");
    expect(final).not.toContain("we should inspect the schema first.");
    expect(final).not.toContain("✓ read a.ts");
  });

  test("flushed timeline thinking is settled; in-progress thinking uses the fallback spinner", () => {
    const timeline = [{ kind: "thinking", text: "internal reasoning passes" }, { kind: "tool", id: "a", summary: "read a.ts", status: "completed" }];
    const makeContext = () => ({ args: { action: "run", agent: "scout", objective: "Inspect" }, isError: false, state: {}, invalidate: vi.fn() } as never);
    // Timeline thinking was flushed by the executor before the tool call, so even the
    // partial view marks it completed: static marker, no spinner, no raw reasoning text.
    const partial = text(renderSubagentResult({ content: [], details: { status: "running", timeline } }, { expanded: true, isPartial: true }, theme, makeContext()));
    expect(partial).toContain("✓ Thinking");
    expect(partial).not.toContain("Thinking…");
    expect(partial).not.toContain("internal reasoning passes");
    // No timeline: thinking is still unflushed and is represented by the fallback
    // spinner carrying the generic "Thinking…" label (frame-agnostic, spinner prefix).
    const thinking = text(renderSubagentResult({ content: [], details: { status: "running" } }, { expanded: false, isPartial: true }, theme, makeContext()));
    const thinkingLine = thinking.split("\n").find((line) => line.trim().endsWith("Thinking…"));
    expect(thinkingLine).toBeDefined();
    expect(thinkingLine!.trim()).toMatch(/^\S+ Thinking…$/);
    expect(thinking).not.toContain("✓ Thinking");
    // Terminal handoffs discard renderer-only timeline activity.
    const settled = text(renderSubagentResult({ content: [], details: { status: "completed", summary: "Done", timeline } }, { expanded: false, isPartial: false }, theme, makeContext()));
    expect(settled).not.toContain("✓ Thinking");
    expect(settled).not.toContain("Thinking…");
    expect(settled).not.toContain("internal reasoning passes");
  });

  test("current unflushed thinking keeps the spinner even alongside settled history", () => {
    const context = { args: { action: "run", agent: "scout", objective: "Inspect" }, isError: false, state: {}, invalidate: vi.fn() } as never;
    const rendered = text(renderSubagentResult({
      content: [{ type: "text", text: "Thinking…" }],
      details: {
        status: "running",
        phase: { kind: "thinking", status: "running" },
        timeline: [{ kind: "tool", id: "a", summary: "read a.ts", status: "completed" }],
      },
    }, { expanded: true, isPartial: true }, theme, context));
    // The flushed tool is settled; the CURRENT, still-unflushed thinking shows the spinner.
    expect(rendered).toContain("✓ read a.ts");
    expect(rendered).toContain("⠋ Thinking…");
    expect(rendered.endsWith("⠋ Thinking…")).toBe(true);
  });

  test("shows current unphased activity after settled history", () => {
    const context = { args: { action: "run", agent: "scout", objective: "Inspect" }, isError: false, state: {}, invalidate: vi.fn() } as never;
    const rendered = text(renderSubagentResult({
      content: [{ type: "text", text: "Writing response…" }],
      details: {
        status: "running",
        timeline: [{ kind: "tool", id: "a", summary: "read a.ts", status: "completed" }],
      },
    }, { expanded: false, isPartial: true }, theme, context));
    expect(rendered).not.toContain("✓ read a.ts");
    expect(rendered).toBe("⠋ Writing response…");

    const expandedContext = { ...context, state: {}, invalidate: vi.fn() } as never;
    const expanded = text(renderSubagentResult({
      content: [{ type: "text", text: "Writing response…" }],
      details: {
        status: "running",
        timeline: [{ kind: "thinking", text: "hidden" }, { kind: "tool", id: "a", summary: "read a.ts", status: "completed" }],
      },
    }, { expanded: true, isPartial: true }, theme, expandedContext));
    expect(expanded).toContain("✓ Thinking");
    expect(expanded).toContain("✓ read a.ts");
    expect(expanded.endsWith("⠋ Writing response…")).toBe(true);
  });

  test("shows foreground elapsed time and lets decisions override ordinary collapsed activity", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-08-31T00:00:31Z"));
    const context = { args: { action: "run", agent: "scout", objective: "Inspect" }, isError: false, state: {}, invalidate: vi.fn() } as never;
    const rendered = text(renderSubagentResult({
      content: [{ type: "text", text: "still working" }],
      details: {
        status: "running", startedAt: Date.now() - 31_000,
        timeline: [{ kind: "tool", id: "a", summary: "read a.ts", status: "completed" }],
        needsDecision: true, decision: { question: "Choose API version" },
      },
    }, { expanded: false, isPartial: true }, theme, context));
    expect(rendered).toBe("! needs input: Choose API version · 31s");
    expect((context as any).state.spinnerTimer).toBeUndefined();
    vi.useRealTimers();
  });

  test("does not keep a spinner timer for static partial history", () => {
    const context = { args: { action: "run", agent: "scout", objective: "Inspect" }, isError: false, state: {}, invalidate: vi.fn() } as never;
    const rendered = text(renderSubagentResult({
      content: [{ type: "text", text: "tool completed" }],
      details: {
        status: "running",
        phase: { kind: "tool", status: "completed" },
      },
    }, { expanded: false, isPartial: true }, theme, context));
    expect(rendered).toContain("✓ tool completed");
    expect(rendered).not.toContain("Thinking…");
    expect((context as { state: { spinnerTimer?: unknown } }).state.spinnerTimer).toBeUndefined();
  });

  test("renders bounded tool history, active and failed calls without a countdown", () => {
    const context = { args: { action: "run", agent: "scout", objective: "Inspect", deadlineMs: 60_000 }, isError: false, state: {}, invalidate: vi.fn() } as never;
    const rendered = text(renderSubagentResult({
      content: [{ type: "text", text: "bash running" }],
      details: {
        status: "running",
        deadlineMs: 60_000,
        toolProgress: {
          earlierCount: 3,
          history: [{ id: "1", summary: "read a.ts", status: "completed" }, { id: "2", summary: "grep missing src", status: "failed" }],
          active: [{ id: "3", summary: "bash npm test", status: "running" }],
        },
      },
    }, { expanded: true, isPartial: true }, theme, context));
    expect(rendered).toContain("… 3 earlier calls");
    expect(rendered).toContain("✓ read a.ts");
    expect(rendered).toContain("✗ grep missing src");
    expect(rendered).toContain("⠋ bash npm test…");
    // The active call row is the last line of the partial view.
    expect(rendered.endsWith("⠋ bash npm test…")).toBe(true);
    expect(rendered).not.toMatch(/\b60s\b/);

    const other = { args: context.args, isError: false, state: {}, invalidate: vi.fn() } as never;
    renderSubagentResult({ content: [{ type: "text", text: "other" }], details: { status: "running" } }, { expanded: false, isPartial: true }, theme, other);
    expect((context as any).state.spinnerTimer).not.toBe((other as any).state.spinnerTimer);
    renderSubagentResult({ content: [], details: { status: "completed", summary: "handoff" } }, { expanded: false, isPartial: false }, theme, context);
    renderSubagentResult({ content: [], details: { status: "failed", error: "failed" } }, { expanded: false, isPartial: false }, theme, other);
    expect((context as any).state.spinnerTimer).toBeUndefined();
    expect((other as any).state.spinnerTimer).toBeUndefined();
  });

  test("hydrates run and identity action titles from authoritative ref details", async () => {
    const env = (await import("../test/harness.ts")).setup();
    const tool = env.extension.getTool();
    const state: Record<string, unknown> = {};
    const invalidate = vi.fn();
    tool.renderResult!({ content: [], details: { jobId: "job", ref: "#7", status: "starting", model: "vendor/model", thinking: "high" } } as never, { expanded: false, isPartial: false }, theme, { args: { action: "run", agent: "scout", objective: "Inspect", background: true }, isError: false, state, invalidate } as never);
    await Promise.resolve();
    const rendered = text(tool.renderCall!({ action: "run", agent: "scout", objective: "Inspect", background: true } as never, theme, { args: {}, isError: false, state, invalidate } as never));
    expect(rendered).toContain("#7 scout — Inspect · tracking in Subagents");

    for (const action of ["get", "cancel"] as const) {
      const actionState: Record<string, unknown> = {};
      const context = { args: { action, jobId: "550e8400-e29b-41d4-a716-446655440000" }, isError: false, state: actionState, invalidate } as never;
      tool.renderResult!({ content: [], details: { jobId: "550e8400-e29b-41d4-a716-446655440000", ref: "#7", status: "completed" } } as never, { expanded: false, isPartial: false }, theme, context);
      expect(text(tool.renderCall!({ action, jobId: "550e8400-e29b-41d4-a716-446655440000" } as never, theme, context))).toContain(`${action} · #7`);
    }
    expect(text(tool.renderCall!({ action: "get", jobId: "#3" } as never, theme))).toContain("get · #3");
    await env.extension.shutdown();
  }, 20_000);

  test("renders structured completions without status backgrounds", () => {
    const taggedTheme = {
      ...theme,
      bg: (color: string, value: string) => `<${color}>${value}</${color}>`,
    } as never;
    const completed = {
      jobId: "job-1", ref: "#1", agent: "scout", task: "Inspect", status: "completed" as const,
      summary: "Done", evidence: "diff", validation: "tests pass", elapsedMs: 2_000,
    };
    const expanded = text(renderSubagentCompletion({ content: "", details: completed }, { expanded: true, outputPad: 0 }, taggedTheme));
    expect(expanded).toContain("#1 scout · completed · 2s — Inspect");
    expect(expanded).toContain("Evidence");
    expect(expanded).toContain("  diff");
    expect(expanded).toContain("Validation");
    expect(expanded).toContain("  tests pass");
    expect(expanded).not.toContain("runtime idle");

    const mixed = text(renderSubagentCompletion({ content: "", details: { batch: [
      completed,
      { ...completed, jobId: "job-2", ref: "#2", status: "failed" as const },
    ] } }, { expanded: false, outputPad: 0 }, taggedTheme));
    expect(mixed).not.toContain("<toolPendingBg>");
    expect(mixed).not.toContain("<toolErrorBg>");
    expect(mixed).not.toContain("<toolSuccessBg>");
  });
});
