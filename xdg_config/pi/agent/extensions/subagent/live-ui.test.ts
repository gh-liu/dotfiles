import { visibleWidth } from "@earendil-works/pi-tui";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import { createLiveUi, formatDuration, LIVE_WIDGET_ID } from "./live-ui.ts";
import { SUBAGENT_SPINNER_FRAMES } from "./protocol.ts";

type WidgetContent = string[] | ((tui: unknown, theme: unknown) => unknown) | undefined;

function createMockUi() {
  const widgetCalls: Array<{ content: WidgetContent; options?: unknown }> = [];
  return {
    widgetCalls,
    setWidget(_key: string, content: WidgetContent, options?: unknown): void {
      widgetCalls.push({ content, options });
    },
    setStatus(): void {},
  };
}

const theme = {
  fg: (_color: string, text: string) => text,
  bold: (text: string) => text,
};

function lastWidgetContent(ui: ReturnType<typeof createMockUi>): WidgetContent {
  return ui.widgetCalls.at(-1)?.content;
}

function renderWidget(ui: ReturnType<typeof createMockUi>, width = 120): string[] {
  const content = lastWidgetContent(ui);
  if (typeof content !== "function") return [];
  const component = (content as (tui: unknown, theme: unknown) => { render(w: number): string[] })(undefined, theme);
  return component.render(width);
}

const tracked = (overrides: Partial<Parameters<ReturnType<typeof createLiveUi>["track"]>[1]> = {}) => ({
  index: 1,
  agent: "scout",
  turn: 1,
  task: "Map the authentication lifecycle and identify the safest implementation seam.",
  startedAt: Date.now(),
  runId: "session-1",
  ...overrides,
});

describe("activity center formatting", () => {
  test("formatDuration renders floor-rounded seconds", () => {
    expect(formatDuration(0)).toBe("0s");
    expect(formatDuration(41_999)).toBe("41s");
    expect(formatDuration(-5)).toBe("0s");
  });
});

describe("activity center", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  test("is inert before a UI is attached", () => {
    const live = createLiveUi();
    expect(() => {
      live.track("r1", tracked());
      live.progress("r1", "Thinking…");
      live.settle("r1", "completed");
      live.remove("r1");
      live.dispose();
    }).not.toThrow();
  });

  test("shows accepted background operations", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", tracked({ index: 1 }));
    live.track("r2", tracked({ runId: "session-2", index: 2, agent: "reviewer", task: "Review the patch for lifecycle races." }));
    live.progress("r1", "grep auth middleware…", { kind: "tool", status: "running" });
    live.progress("r2", "Thinking…", { kind: "thinking", status: "running" });
    vi.advanceTimersByTime(250);

    const lines = renderWidget(ui);
    expect(lines[0]).toBe("Background subagents · 2 active");
    expect(lines.join("\n")).toContain("#1 scout · turn 1 · 0s");
    expect(lines.join("\n")).toContain("#2 reviewer · turn 1 · 0s");
    expect(lines.join("\n")).toContain("Map the authentication lifecycle");
    expect(lines.join("\n")).toContain("Review the patch for lifecycle races.");
    expect(lines.join("\n")).toContain("↳ grep auth middleware…");
    expect(lines.join("\n")).toContain("↳ Thinking…");
  });

  test("keeps completed Thinking and tool phase markers without duplicating the spinner", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", tracked());

    live.progress("r1", "Thinking", { kind: "thinking", status: "completed" });
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui).join("\n")).toContain("↳ ✓ Thinking");

    live.progress("r1", "grep schema complete", { kind: "tool", status: "completed" });
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui).join("\n")).toContain("↳ ✓ grep schema complete");

    live.progress("r1", "npm test failed", { kind: "tool", status: "failed" });
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui).join("\n")).toContain("↳ ✗ npm test failed");
  });

  test("animates one job-level spinner through startup, tools, and synthesis", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", tracked());
    const frames = new Set<string>();
    for (let index = 0; index < 5; index += 1) {
      const header = renderWidget(ui).find((line) => line.includes("#1")) ?? "";
      const frame = SUBAGENT_SPINNER_FRAMES.find((candidate) => header.includes(candidate));
      expect(frame).toBeDefined();
      frames.add(frame!);
      vi.advanceTimersByTime(250);
    }
    expect(frames.size).toBeGreaterThan(2);
  });

  test("shows only latest activity and concurrent tool count", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", tracked());
    live.progress("r1", "old activity");
    live.progress("r1", "read schema.ts…", { kind: "tool", status: "running" }, 3);
    vi.advanceTimersByTime(250);
    const rendered = renderWidget(ui).join("\n");
    expect(rendered).toContain("read schema.ts… · 3 active");
    expect(rendered).not.toContain("old activity");
  });

  test("prioritizes decisions and preserves actionable text on narrow terminals", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", tracked({ index: 1 }));
    live.track("r2", tracked({ index: 12, agent: "reviewer" }));
    live.progress("r2", "waiting", undefined, undefined, "Choose API version");
    vi.advanceTimersByTime(250);
    const lines = renderWidget(ui, 32);
    const decisionHeader = lines.find((line) => line.includes("#12"));
    expect(decisionHeader).toContain("needs input");
    expect(lines.find((line) => line.includes("Choose API"))).toBeDefined();
    expect(lines.findIndex((line) => line.includes("#12"))).toBeLessThan(lines.findIndex((line) => line.includes("#1 scout")));
    for (const line of lines) expect(visibleWidth(line)).toBeLessThanOrEqual(32);
  });

  test("uses two task lines when wide and one when compact", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", tracked({ task: "A deliberately long task that explains what the child should inspect, why the investigation matters, and what evidence it should return to the parent." }));
    const wide = renderWidget(ui, 80).filter((line) => line.startsWith("  ") && !line.includes("↳"));
    const compact = renderWidget(ui, 48).filter((line) => line.startsWith("  ") && !line.includes("↳"));
    expect(wide).toHaveLength(2);
    expect(compact).toHaveLength(1);
    expect(compact[0]).toContain("…");
  });

  test("bounds dense layouts while retaining priority jobs", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    for (let index = 1; index <= 7; index += 1) {
      live.track(`r${index}`, tracked({ index, task: `Investigate bounded work stream ${index} and return evidence.` }));
    }
    live.progress("r7", "waiting", undefined, undefined, "Resolve the release policy");
    vi.advanceTimersByTime(250);
    const lines = renderWidget(ui, 100);
    expect(lines[0]).toContain("7 active");
    expect(lines.find((line) => line.includes("#7 scout"))).toBeDefined();
    expect(lines.find((line) => line.includes("#6 scout"))).toBeUndefined();
    expect(lines.at(-1)).toContain("… 2 more sessions · use get for details");
    expect(lines.filter((line) => line.includes("↳"))).toHaveLength(0);
  });

  test("keeps settlement until its card is acknowledged", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", tracked({ index: 1 }));
    live.track("r2", tracked({ index: 2 }));
    live.settle("r1", "completed");
    expect(renderWidget(ui).join("\n")).toContain("✓ #1 scout · turn 1 · result ready · awaiting card · get #1");
    live.remove("r1");
    expect(renderWidget(ui).join("\n")).not.toContain("#1");

    live.settle("r2", "completed");
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui).join("\n")).toContain("✓ #2 scout · turn 1 · result ready · awaiting card · get #2");
    live.reportFailed("r2");
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui).join("\n")).toContain("! #2 scout · turn 1 · card failed · get #2");
    live.remove("r2");
    expect(lastWidgetContent(ui)).toBeUndefined();
  });

  test("operation keys isolate overlapping rows from the same session", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("old", tracked({ runId: "same", index: 1, task: "First turn" }));
    live.settle("old", "completed");
    live.track("new", tracked({ runId: "same", index: 1, turn: 2, task: "Followup turn" }));
    live.remove("old");
    const rendered = renderWidget(ui).join("\n");
    expect(rendered).toContain("Followup turn");
    expect(rendered).toContain("#1 scout · turn 2");
    expect(rendered).not.toContain("First turn");
    live.removeSession("same");
    expect(lastWidgetContent(ui)).toBeUndefined();
  });

  test("throttles burst updates and heartbeat refreshes elapsed time", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", tracked());
    expect(ui.widgetCalls).toHaveLength(1);
    live.progress("r1", "one");
    live.progress("r1", "two");
    expect(ui.widgetCalls).toHaveLength(1);
    vi.advanceTimersByTime(250);
    expect(ui.widgetCalls.length).toBeGreaterThan(1);
    vi.advanceTimersByTime(1_000);
    expect(renderWidget(ui).find((line) => line.includes("#1"))).toContain("1s");
  });

  test("registers above the editor and dispose clears timers and widget", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", tracked());
    expect(ui.widgetCalls.find((call) => typeof call.content === "function")?.options).toEqual({ placement: "aboveEditor" });
    expect(LIVE_WIDGET_ID).toBe("subagent-live");
    live.dispose();
    expect(lastWidgetContent(ui)).toBeUndefined();
    const count = ui.widgetCalls.length;
    vi.advanceTimersByTime(5_000);
    expect(ui.widgetCalls).toHaveLength(count);
  });
});
