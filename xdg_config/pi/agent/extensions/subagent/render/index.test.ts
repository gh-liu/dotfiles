import { describe, expect, test, vi } from "vitest";
import { renderSubagentCall, renderSubagentCompletion, renderSubagentResult } from "./index.ts";

const theme = { fg: (_color: string, value: string) => value, bg: (_color: string, value: string) => value, bold: (value: string) => value } as never;
const text = (component: { render(width: number): string[] }) => component.render(200).join("\n").trim();

const runContext = (state: Record<string, unknown> = {}) => ({
  args: { action: "run", agent: "scout", objective: "Inspect auth" },
  isError: false,
  state,
  invalidate: vi.fn(),
} as never);

describe("task API rendering", () => {
  test("renders durable invocation records without transient status", () => {
    const call = text(renderSubagentCall({ action: "run", agent: "scout", objective: "Inspect auth", background: true }, theme));
    expect(call).toBe("scout — Inspect auth");
    expect(call).not.toContain("running");
    expect(call).not.toContain("tracking");
    expect(text(renderSubagentCall({ action: "get", jobId: "2", waitMs: 30_000 }, theme))).toContain("get · #2 · wait 30s");
    expect(text(renderSubagentCall({ action: "cancel", jobId: "#2" }, theme))).toContain("cancel · #2");
  });

  test("retains a useful multi-line prompt budget in the invocation record", () => {
    const objective = "Inspect the authentication lifecycle from middleware registration through token refresh, identify concurrency risks, and cite the exact implementation and test files that support every conclusion.";
    const rendered = text(renderSubagentCall({ action: "run", agent: "scout", objective }, theme));
    const normalized = rendered.replace(/\s+/g, " ");
    expect(normalized).toContain("middleware registration through token refresh");
    expect(normalized).toContain("support every conclusion");
  });

  test("expanded invocation shows the bounded delegation spec", () => {
    const args = {
      action: "run" as const, agent: "worker", objective: "Implement cache invalidation", scope: ["src/cache.ts"],
      context: "TTL is authoritative", constraints: ["No API changes"], acceptance: ["Tests pass"],
    };
    const rendered = text(renderSubagentCall(args, theme, { args, expanded: true, isError: false, state: {}, invalidate: vi.fn() } as never));
    for (const expected of ["Outcome", "Implement cache invalidation", "Scope", "src/cache.ts", "Context", "TTL is authoritative", "Constraints", "No API changes", "Acceptance", "Tests pass"]) {
      expect(rendered).toContain(expected);
    }
  });

  test("renders workflow graph calls and node status results", () => {
    const args = {
      action: "workflow" as const,
      objective: "Ship auth",
      nodes: [
        { id: "inspect", agent: "scout", objective: "Inspect auth" },
        { id: "change", agent: "worker", objective: "Implement auth", dependsOn: ["inspect"] },
      ],
    };
    const call = text(renderSubagentCall(args, theme, { args, expanded: true, isError: false, state: {}, invalidate: vi.fn() } as never));
    expect(call).toContain("Workflow — Ship auth · 2 nodes");
    expect(call).toContain("change worker ← inspect");

    const result = text(renderSubagentResult({ content: [], details: {
      ref: "W#2", status: "running", nodes: [
        { id: "inspect", agent: "scout", objective: "Inspect auth", status: "completed" },
        { id: "change", agent: "worker", objective: "Implement auth", status: "running" },
      ],
    } }, { expanded: true, isPartial: false }, theme, { args, isError: false, state: {}, invalidate: vi.fn() } as never));
    expect(result).toContain("workflow running · W#2 · 1/2 nodes");
    expect(result).toContain("✓ inspect · scout · completed");
    expect(result).toContain("● change · worker · running");
  });

  test("partial tool results point to the activity center and never duplicate activity", () => {
    const context = runContext();
    const details = {
      status: "running",
      activity: "read a.ts…",
      phase: { kind: "thinking", status: "running" },
      timeline: [{ kind: "tool", id: "a", summary: "read a.ts", status: "completed" }],
    };
    const rendered = text(renderSubagentResult({ content: [{ type: "text", text: "Thinking…" }], details }, { expanded: true, isPartial: true }, theme, context));
    expect(rendered).toContain("● running");
    expect(rendered).not.toContain("Timeline");
    expect(rendered).toContain("✓ completed: read a.ts");
    expect(rendered).not.toContain("Thinking…");
    const collapsed = text(renderSubagentResult({ content: [], details }, { expanded: false, isPartial: true }, theme, context));
    expect(collapsed).toBe("↗ active in Subagents");
    expect((context as { state: { spinnerTimer?: unknown } }).state.spinnerTimer).toBeUndefined();
  });

  test("renders terminal foreground and recovered background handoffs", () => {
    const foreground = text(renderSubagentResult({ content: [], details: { status: "completed", summary: "Done", elapsedMs: 1_000 } }, { expanded: false, isPartial: false }, theme, runContext()));
    expect(foreground).toContain("✓ completed · 1s");
    expect(foreground).toContain("Done");
    const runExpanded = text(renderSubagentResult({ content: [], details: {
      status: "completed",
      summary: "Done",
      timeline: [
        { kind: "tool", id: "a", summary: "read auth.ts", status: "completed" },
        { kind: "thinking", text: "private reasoning" },
      ],
    } }, { expanded: true, isPartial: false }, theme, runContext()));
    expect(runExpanded).not.toContain("Timeline");
    expect(runExpanded).toContain("✓ completed: read auth.ts");
    expect(runExpanded).not.toContain("private reasoning");

    const recovered = text(renderSubagentResult({
      content: [], details: { status: "completed", handoff: { summary: "Recovered background result" }, elapsedMs: 2_000 },
    }, { expanded: false, isPartial: false }, theme, {
      args: { action: "get", jobId: "#2" }, isError: false, state: {}, invalidate: vi.fn(),
    } as never));
    expect(recovered).toContain("✓ completed · 2s");
    expect(recovered).toContain("Recovered background result");
  });

  test("renders get diagnostics and cancel semantics", () => {
    const getContext = { args: { action: "get", jobId: "#2" }, isError: false, state: {}, invalidate: vi.fn() } as never;
    const expanded = text(renderSubagentResult({ content: [], details: {
      status: "running", activity: "reading auth.ts", recentActivity: ["Thinking", "completed: grep auth"],
      timeline: [
        { kind: "tool", id: "a", summary: "read auth.ts", status: "completed" },
        { kind: "thinking", text: "private reasoning" },
        { kind: "tool", id: "b", summary: "npm test", status: "failed" },
      ],
      workOrder: { goal: "Map auth", scope: ["src"], constraints: ["Read only"], validation: ["Cite files"], returnFormat: "Summary" },
    } }, { expanded: true, isPartial: false }, theme, getContext));
    expect(expanded).toContain("Current");
    expect(expanded).toContain("Recent activity");
    expect(expanded).not.toContain("Timeline");
    expect(expanded).toContain("✓ completed: read auth.ts");
    expect(expanded).toContain("✗ failed: npm test");
    expect(expanded).toContain("Thinking");
    expect(expanded).not.toContain("private reasoning");
    expect(expanded).toContain("Work order");
    const collapsed = text(renderSubagentResult({ content: [], details: {
      status: "running", timeline: [{ kind: "tool", id: "a", summary: "read auth.ts", status: "completed" }],
    } }, { expanded: false, isPartial: false }, theme, getContext));
    expect(collapsed).not.toContain("Timeline");

    const cancel = text(renderSubagentResult({ content: [], details: { ref: "#2", status: "interrupted", cancelled: true } }, { expanded: false, isPartial: false }, theme, {
      args: { action: "cancel", jobId: "#2" }, isError: false, state: {}, invalidate: vi.fn(),
    } as never));
    expect(cancel).toContain("cancel acknowledged");
  });

  test("hydrates every run title with the authoritative short ref", async () => {
    const env = (await import("../test/harness.ts")).setup();
    const tool = env.extension.getTool();
    const state: Record<string, unknown> = {};
    const invalidate = vi.fn();
    tool.renderResult!({ content: [], details: { jobId: "job", ref: "#7", status: "starting", model: "vendor/model", thinking: "high" } } as never, { expanded: false, isPartial: true }, theme, {
      args: { action: "run", agent: "scout", objective: "Inspect", background: false }, isError: false, state, invalidate,
    } as never);
    await Promise.resolve();
    const rendered = text(tool.renderCall!({ action: "run", agent: "scout", objective: "Inspect", background: false } as never, theme, { args: {}, isError: false, state, invalidate } as never));
    expect(rendered).toContain("#7 scout — Inspect");
    expect(rendered).not.toContain("tracking");
    await env.extension.shutdown();
  }, 20_000);

  test("renders result-first completion cards without status backgrounds", () => {
    const taggedTheme = { ...theme, bg: (color: string, value: string) => `<${color}>${value}</${color}>` } as never;
    const completed = {
      jobId: "job-1", ref: "#1", agent: "scout", task: "Inspect auth", status: "completed" as const,
      summary: "Mapped the auth lifecycle.", evidence: "src/auth.ts", validation: "tests pass", elapsedMs: 2_000,
    };
    const collapsed = text(renderSubagentCompletion({ content: "", details: completed }, { expanded: false, outputPad: 0 }, taggedTheme));
    expect(collapsed).toContain("✓ scout · 2s");
    expect(collapsed).toContain("Mapped the auth lifecycle.");
    expect(collapsed).toContain("#1 · expand for details");
    expect(collapsed).not.toContain("· completed");

    const expanded = text(renderSubagentCompletion({ content: "", details: completed }, { expanded: true, outputPad: 0 }, taggedTheme));
    expect(expanded).toContain("Objective");
    expect(expanded).toContain("Inspect auth");
    expect(expanded).toContain("Evidence");
    expect(expanded).toContain("Validation");
    expect(expanded).toContain("#1");

    const mixed = text(renderSubagentCompletion({ content: "", details: { batch: [
      completed,
      { ...completed, jobId: "job-2", ref: "#2", status: "failed" as const },
    ] } }, { expanded: false, outputPad: 0 }, taggedTheme));
    expect(mixed).toContain("✗ scout · failed · 2s");
    expect(mixed).not.toContain("<toolPendingBg>");
    expect(mixed).not.toContain("<toolErrorBg>");
    expect(mixed).not.toContain("<toolSuccessBg>");
  });
});
