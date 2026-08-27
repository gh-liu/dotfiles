import { describe, expect, test, vi } from "vitest";
import { renderSubagentCall, renderSubagentResult } from "./index.ts";

const theme = { fg: (_color: string, text: string) => text, bg: (_color: string, text: string) => text, bold: (text: string) => text } as never;
const text = (component: { render(width: number): string[] }) => component.render(200).join("\n").trim();

describe("task API rendering", () => {
  test("renders all public calls", () => {
    expect(text(renderSubagentCall({ action: "run", agent: "scout", objective: "Inspect", background: true }, theme))).toContain("scout · bg — Inspect");
    expect(text(renderSubagentCall({ action: "get", jobId: "job-1" }, theme))).toContain("get · job-1");
    expect(text(renderSubagentCall({ action: "cancel", jobId: "job-1" }, theme))).toContain("cancel · job-1");
  });

  test("renders progress and terminal handoff", () => {
    const context = { args: { action: "run", agent: "scout", objective: "Inspect", deadlineMs: 60_000 }, isError: false, state: {}, invalidate: vi.fn() } as never;
    expect(text(renderSubagentResult({ content: [{ type: "text", text: "working" }], details: { status: "running" } }, { expanded: false, isPartial: true }, theme, context))).toContain("working");
    const rendered = text(renderSubagentResult({ content: [], details: { status: "completed", summary: "Done", elapsedMs: 1_000 } }, { expanded: false, isPartial: false }, theme, context));
    expect(rendered).toContain("✓ completed · 1s");
    expect(rendered).toContain("Done");
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
    }, { expanded: false, isPartial: true }, theme, context));
    expect(rendered).toContain("… 3 earlier calls");
    expect(rendered).toContain("✓ read a.ts");
    expect(rendered).toContain("✗ grep missing src");
    expect(rendered).toContain("⠋ bash npm test…");
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
    tool.renderResult!({ content: [], details: { jobId: "job", ref: "#7", status: "starting", model: "vendor/model", thinking: "high" } } as never, { expanded: false, isPartial: false }, theme, { args: { action: "run", agent: "scout", objective: "Inspect" }, isError: false, state, invalidate } as never);
    await Promise.resolve();
    const rendered = text(tool.renderCall!({ action: "run", agent: "scout", objective: "Inspect" } as never, theme, { args: {}, isError: false, state, invalidate } as never));
    expect(rendered).toContain("#7 scout · model · high");

    for (const action of ["get", "cancel"] as const) {
      const actionState: Record<string, unknown> = {};
      const context = { args: { action, jobId: "550e8400-e29b-41d4-a716-446655440000" }, isError: false, state: actionState, invalidate } as never;
      tool.renderResult!({ content: [], details: { jobId: "550e8400-e29b-41d4-a716-446655440000", ref: "#7", status: "completed" } } as never, { expanded: false, isPartial: false }, theme, context);
      expect(text(tool.renderCall!({ action, jobId: "550e8400-e29b-41d4-a716-446655440000" } as never, theme, context))).toContain(`${action} · #7`);
    }
    expect(text(tool.renderCall!({ action: "get", jobId: "#3" } as never, theme))).toContain("get · #3");
    await env.extension.shutdown();
  }, 20_000);
});
