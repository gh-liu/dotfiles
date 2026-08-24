import { visibleWidth } from "@earendil-works/pi-tui";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import {
  createLiveUi,
  formatDuration,
  LIVE_WIDGET_ID,
} from "./live-ui.ts";

type WidgetContent = string[] | ((tui: unknown, theme: unknown) => unknown) | undefined;

function createMockUi() {
  const widgetCalls: Array<{ content: WidgetContent; options?: unknown }> = [];
  return {
    widgetCalls,
    setWidget(_key: string, content: WidgetContent, options?: unknown): void {
      widgetCalls.push({ content, options });
    },
    setStatus(_key: string, _text: string | undefined): void {},
  };
}

const stubTheme = {
  fg: (_color: string, text: string) => text,
  bold: (text: string) => text,
};

function lastWidgetContent(ui: ReturnType<typeof createMockUi>): WidgetContent {
  const calls = ui.widgetCalls;
  return calls.length === 0 ? undefined : calls[calls.length - 1].content;
}

function renderWidget(ui: ReturnType<typeof createMockUi>, width = 120, theme: typeof stubTheme = stubTheme): string[] {
  const content = lastWidgetContent(ui);
  if (typeof content !== "function") return [];
  const component = (content as (tui: unknown, theme: unknown) => { render(w: number): string[] })(
    undefined,
    theme,
  );
  return component.render(width);
}

describe("live ui formatting helpers", () => {
  test("formatDuration renders plain seconds with unit suffix", () => {
    expect(formatDuration(0)).toBe("0s");
    expect(formatDuration(41_999)).toBe("41s");
    expect(formatDuration(42_000)).toBe("42s");
    expect(formatDuration(65_000)).toBe("65s");
    expect(formatDuration(3_600_000)).toBe("3600s");
    expect(formatDuration(-5)).toBe("0s");
  });
});

describe("live ui controller", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  test("is a no-op when attach was never called", () => {
    const live = createLiveUi();
    expect(() => {
      live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
      live.progress("r1", "Thinking…");
      live.settle("r1", "completed");
      live.remove("r1");
      live.dispose();
    }).not.toThrow();
  });

  test("renders one overview line per runtime with time budget and activity", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    const startedAt = Date.now();
    live.track("r1", { agent: "scout", startedAt, deadlineMs: 300_000, mode: "foreground", index: 1 });
    live.track("r2", { agent: "worker", startedAt, deadlineMs: 60_000, mode: "foreground", index: 1 });
    vi.advanceTimersByTime(250);

    const lines = renderWidget(ui);
    expect(lines).toHaveLength(2);
    expect(lines[0]).toContain("scout");
    expect(lines[0]).toContain("0s / 300s");
    expect(lines[0]).toContain("starting");
    expect(lines[1]).toContain("worker");
    expect(lines[1]).toContain("0s / 60s");

    live.progress("r1", "Thinking…");
    vi.advanceTimersByTime(250);
    const updated = renderWidget(ui);
    expect(updated).toHaveLength(2);
    expect(updated[0]).toContain("scout");
    expect(updated[0]).toContain("Thinking…");
  });

  test("floor-rounds elapsed and ceil-rounds remaining without early expiry", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    const startedAt = Date.now();
    live.track("r1", { agent: "scout", startedAt, deadlineMs: 300_000, mode: "foreground", index: 1 });

    // At 191.6s, flooring both values previously rendered `191s / 108s`.
    vi.advanceTimersByTime(191_600);
    expect(renderWidget(ui)[0]).toContain("191s / 109s");

    // Remaining time is clamped at zero both at and after the deadline.
    vi.advanceTimersByTime(108_400);
    expect(renderWidget(ui)[0]).toContain("300s / 0s");
    vi.advanceTimersByTime(1);
    expect(renderWidget(ui)[0]).toContain("300s / 0s");
  });

  test("shows only the latest activity per runtime", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
    for (let i = 1; i <= 8; i++) live.progress("r1", `step ${i}`);

    vi.advanceTimersByTime(250);
    const lines = renderWidget(ui);
    expect(lines).toHaveLength(1); // one compact line, no history lines
    expect(lines[0]).toContain("step 8");
    expect(lines[0]).not.toContain("step 7");
  });

  test("throttles setWidget with leading plus trailing coalescing", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);

    // Leading render on track.
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
    expect(ui.widgetCalls).toHaveLength(1);

    // Bursts inside the throttle window coalesce into one trailing render.
    vi.advanceTimersByTime(10);
    live.progress("r1", "one");
    vi.advanceTimersByTime(10);
    live.progress("r1", "two");
    vi.advanceTimersByTime(10);
    live.progress("r1", "three");
    expect(ui.widgetCalls).toHaveLength(1);

    vi.advanceTimersByTime(250);
    expect(ui.widgetCalls).toHaveLength(2);

    // After the window passes the next update leads immediately.
    vi.advanceTimersByTime(300);
    live.progress("r1", "four");
    expect(ui.widgetCalls).toHaveLength(3);
  });

  test("heartbeat re-renders every second while tracked and stops when idle", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
    vi.advanceTimersByTime(250); // flush trailing timer from track

    const baseline = ui.widgetCalls.length;
    vi.advanceTimersByTime(3_000);
    expect(ui.widgetCalls.length - baseline).toBe(3);

    live.settle("r1", "completed");
    expect(lastWidgetContent(ui)).toBeUndefined();

    const afterSettle = ui.widgetCalls.length;
    vi.advanceTimersByTime(5_000);
    expect(ui.widgetCalls.length).toBe(afterSettle);
  });

  test("clears the widget only after the last runtime settles", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
    live.track("r2", { agent: "worker", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });

    live.settle("r1", "completed");
    expect(typeof lastWidgetContent(ui)).toBe("function");

    live.settle("r2", "failed");
    expect(lastWidgetContent(ui)).toBeUndefined();

    // Idempotent settle/remove produce no further widget churn.
    const calls = ui.widgetCalls.length;
    live.settle("r2", "failed");
    live.remove("r2");
    expect(ui.widgetCalls.length).toBe(calls);
  });

  test("dispose clears the widget and stops all timers", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
    live.track("r2", { agent: "worker", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });

    live.dispose();
    expect(lastWidgetContent(ui)).toBeUndefined();

    const calls = ui.widgetCalls.length;
    vi.advanceTimersByTime(10_000);
    expect(ui.widgetCalls.length).toBe(calls);

    // Post-dispose updates stay inert.
    live.track("r3", { agent: "late", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
    live.progress("r3", "stray");
    expect(ui.widgetCalls.length).toBe(calls);
  });

  test("renders width-safe truncated lines", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "an-exceptionally-long-agent-name-for-truncation", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
    live.progress("r1", "x".repeat(300));
    vi.advanceTimersByTime(250);

    for (const line of renderWidget(ui, 40)) {
      // truncateToWidth may append ANSI reset bytes; assert on visible width.
      expect(visibleWidth(line)).toBeLessThanOrEqual(40);
    }
  });

  test("widget is registered with aboveEditor placement", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });

    const registration = ui.widgetCalls.find((call) => typeof call.content === "function");
    expect(registration?.options).toEqual({ placement: "aboveEditor" });
    expect(LIVE_WIDGET_ID).toBe("subagent-live");
  });

  test("background runtime shows a badge while running and an idle line after settle", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "background", index: 1 });
    vi.advanceTimersByTime(250);

    let lines = renderWidget(ui);
    expect(lines[0]).toContain("⟨bg⟩");
    expect(lines[0]).toContain("scout");

    live.settle("r1", "completed");
    vi.advanceTimersByTime(250); // idle transition goes through the throttle
    lines = renderWidget(ui);
    expect(lines).toHaveLength(1);
    expect(lines[0]).toContain("idle");
    expect(lines[0]).toContain("holds slot");

    // Foreground runtimes carry no badge.
    live.track("r2", { agent: "worker", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
    vi.advanceTimersByTime(250);
    lines = renderWidget(ui);
    expect(lines.find((line) => line.includes("worker"))).not.toContain("⟨bg⟩");
  });

  test("colors idle outcome markers and preserves elapsed fallback", () => {
    const outcomes = [
      ["completed", "success", "✓"],
      ["failed", "error", "✗"],
      ["interrupted", "warning", "■"],
    ] as const;

    for (const [outcome, color, marker] of outcomes) {
      const ui = createMockUi();
      const live = createLiveUi();
      const colorTheme = {
        fg: (name: string, text: string) => name === "dim" ? text : `<${name}>${text}</${name}>`,
        bold: (text: string) => text,
      };
      live.attach(ui);
      live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "background", index: 1 });
      live.settle("r1", outcome, 4_200);
      vi.advanceTimersByTime(250);

      expect(renderWidget(ui, 120, colorTheme)[0]).toBe(`○ #1 scout ⟨bg⟩ · idle · 4s <${color}>${marker}</${color}> · holds slot`);
    }

    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "background", index: 1 });
    live.settle("r1", "completed");
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui)[0]).toBe("○ #1 scout ⟨bg⟩ · idle ✓ · holds slot");
  });

  test("closing an idle background runtime removes its line immediately", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "background", index: 1 });
    live.settle("r1", "completed");

    live.remove("r1");
    expect(lastWidgetContent(ui)).toBeUndefined();
    expect(renderWidget(ui)).toHaveLength(0);
  });

  test("a follow-up re-track returns an idle background runtime to running", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "background", index: 1 });
    live.settle("r1", "completed");
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui)[0]).toContain("idle");

    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 120_000, mode: "background", index: 1 });
    vi.advanceTimersByTime(250);
    const lines = renderWidget(ui);
    expect(lines).toHaveLength(1);
    expect(lines[0]).toContain("●");
    expect(lines[0]).not.toContain("idle");
  });
});
