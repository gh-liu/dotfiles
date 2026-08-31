import { visibleWidth } from "@earendil-works/pi-tui";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import {
  createLiveUi,
  formatDuration,
  LIVE_WIDGET_ID,
} from "./live-ui.ts";
import { SUBAGENT_SPINNER_FRAMES } from "./protocol.ts";

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
    expect(lines[0]).toContain("0s elapsed · 300s left");
    expect(lines[0]).toContain("starting");
    expect(lines[1]).toContain("worker");
    expect(lines[1]).toContain("0s elapsed · 60s left");

    live.progress("r1", "Thinking…");
    vi.advanceTimersByTime(250);
    const updated = renderWidget(ui);
    expect(updated).toHaveLength(2);
    expect(updated[0]).toContain("scout");
    expect(updated[0]).toContain("Thinking…");
  });

  test("renders thinking/tool phase affordances consistent with the result renderer", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });

    // Thinking in progress: live spinner frame + Thinking…
    live.progress("r1", "Thinking…", { kind: "thinking", status: "running" });
    vi.advanceTimersByTime(250);
    const thinkingLine = renderWidget(ui)[0];
    expect(thinkingLine).toContain("Thinking…");
    expect(SUBAGENT_SPINNER_FRAMES.some((frame) => thinkingLine.includes(`${frame} Thinking…`))).toBe(true);

    // Thinking flushed: completed marker matches the result's ✓ Thinking, no spinner.
    live.progress("r1", "Thinking", { kind: "thinking", status: "completed" });
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui)[0]).toContain("✓ Thinking");
    expect(renderWidget(ui)[0]).not.toContain("Thinking…");

    // Tool lifecycle: running spinner, then completed/failed markers.
    live.progress("r1", "grep schema · src…", { kind: "tool", status: "running" });
    vi.advanceTimersByTime(250);
    const toolLine = renderWidget(ui)[0];
    expect(toolLine).toContain("grep schema · src…");
    expect(SUBAGENT_SPINNER_FRAMES.some((frame) => toolLine.includes(`${frame} grep schema · src…`))).toBe(true);

    live.progress("r1", "grep schema · src done · working…", { kind: "tool", status: "completed" });
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui)[0]).toContain("✓ grep schema · src done · working…");

    live.progress("r1", "bash npm test failed · reviewing…", { kind: "tool", status: "failed" });
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui)[0]).toContain("✗ bash npm test failed · reviewing…");

    // Without a phase the summary renders verbatim, preserving prior behavior.
    live.progress("r1", "Writing response…", undefined);
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui)[0]).toContain("Writing response…");
    expect(renderWidget(ui)[0]).not.toContain("Thinking…");
  });

  test("widget animates spinner frames while thinking or tool is running", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });

    live.progress("r1", "Thinking…", { kind: "thinking", status: "running" });
    vi.advanceTimersByTime(250);
    const seen: string[] = [];
    for (let i = 0; i < SUBAGENT_SPINNER_FRAMES.length + 2; i++) {
      const line = renderWidget(ui)[0];
      const frame = SUBAGENT_SPINNER_FRAMES.find((candidate) => line.includes(`${candidate} Thinking…`));
      expect(frame).toBeDefined();
      seen.push(frame!);
      vi.advanceTimersByTime(100);
    }
    // The glyph changes across consecutive renders and cycles through the shared set.
    expect(new Set(seen).size).toBeGreaterThan(2);
    for (const frame of seen) expect(SUBAGENT_SPINNER_FRAMES).toContain(frame);

    // Tool running uses the same animated frame set.
    live.progress("r1", "grep schema · src…", { kind: "tool", status: "running" });
    vi.advanceTimersByTime(250);
    const toolFrame = SUBAGENT_SPINNER_FRAMES.find((candidate) => renderWidget(ui)[0].includes(`${candidate} grep schema · src…`));
    expect(toolFrame).toBeDefined();
    vi.advanceTimersByTime(100);
    const toolLine2 = renderWidget(ui)[0];
    const toolFrame2 = SUBAGENT_SPINNER_FRAMES.find((candidate) => toolLine2.includes(`${candidate} grep schema · src…`));
    expect(toolFrame2).toBeDefined();
    expect(toolFrame2).not.toBe(toolFrame);
  });

  test("completed/failed phases use static markers and stop the spinner ticker", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });

    live.progress("r1", "Thinking…", { kind: "thinking", status: "running" });
    vi.advanceTimersByTime(250);
    expect(SUBAGENT_SPINNER_FRAMES.some((frame) => renderWidget(ui)[0].includes(`${frame} Thinking…`))).toBe(true);

    // Flushed thinking: static success marker and the spinner ticker stops.
    live.progress("r1", "Thinking", { kind: "thinking", status: "completed" });
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui)[0]).toContain("✓ Thinking");
    const callsAfterCompleted = ui.widgetCalls.length;
    vi.advanceTimersByTime(300); // spinner tick (100ms) would repaint; heartbeat (1s) has not fired
    expect(ui.widgetCalls.length).toBe(callsAfterCompleted);

    // Tool running animates again, then a failure freezes to the static marker.
    live.progress("r1", "grep schema · src…", { kind: "tool", status: "running" });
    vi.advanceTimersByTime(250);
    expect(SUBAGENT_SPINNER_FRAMES.some((frame) => renderWidget(ui)[0].includes(`${frame} grep schema · src…`))).toBe(true);

    live.progress("r1", "grep schema failed · reviewing…", { kind: "tool", status: "failed" });
    vi.advanceTimersByTime(250);
    expect(renderWidget(ui)[0]).toContain("✗ grep schema failed · reviewing…");
    const callsAfterFailed = ui.widgetCalls.length;
    vi.advanceTimersByTime(300);
    expect(ui.widgetCalls.length).toBe(callsAfterFailed);
  });

  test("spinner ticker stops once no running runtime remains", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
    live.progress("r1", "Thinking…", { kind: "thinking", status: "running" });
    vi.advanceTimersByTime(250);

    // Foreground settle detaches the runtime: heartbeat and spinner both stop.
    live.settle("r1", "completed");
    expect(lastWidgetContent(ui)).toBeUndefined();
    const callsAfterSettle = ui.widgetCalls.length;
    vi.advanceTimersByTime(5_000);
    expect(ui.widgetCalls.length).toBe(callsAfterSettle);

    // A background runtime also detaches on settlement; its terminal state is
    // rendered by the background completion card instead of this live panel.
    live.track("r2", { agent: "worker", startedAt: Date.now(), deadlineMs: 60_000, mode: "background", index: 2 });
    live.progress("r2", "Thinking…", { kind: "thinking", status: "running" });
    vi.advanceTimersByTime(250);
    expect(SUBAGENT_SPINNER_FRAMES.some((frame) => renderWidget(ui)[0].includes(`${frame} Thinking…`))).toBe(true);

    live.settle("r2", "completed");
    expect(lastWidgetContent(ui)).toBeUndefined();
    const callsAfterBackgroundSettle = ui.widgetCalls.length;
    vi.advanceTimersByTime(300); // spinner tick (100ms) would repaint; heartbeat (1s) has not fired
    expect(ui.widgetCalls.length).toBe(callsAfterBackgroundSettle);

    // dispose also stops every timer.
    live.dispose();
    expect(lastWidgetContent(ui)).toBeUndefined();
    const callsAfterDispose = ui.widgetCalls.length;
    vi.advanceTimersByTime(5_000);
    expect(ui.widgetCalls.length).toBe(callsAfterDispose);
  });

  test("floor-rounds elapsed and ceil-rounds remaining without early expiry", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    const startedAt = Date.now();
    live.track("r1", { agent: "scout", startedAt, deadlineMs: 300_000, mode: "foreground", index: 1 });

    // At 191.6s, flooring both values previously rendered 108 seconds remaining.
    vi.advanceTimersByTime(191_600);
    expect(renderWidget(ui)[0]).toContain("191s elapsed · 109s left");

    // Remaining time is clamped at zero both at and after the deadline.
    vi.advanceTimersByTime(108_400);
    expect(renderWidget(ui)[0]).toContain("300s elapsed · 0s left");
    vi.advanceTimersByTime(1);
    expect(renderWidget(ui)[0]).toContain("300s elapsed · 0s left");
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

  test("shows concurrent active tool count without claiming same-name parallelism", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });

    // Single active tool stays concise: no count suffix.
    live.progress("r1", "web_search query…", { kind: "tool", status: "running" }, 1);
    vi.advanceTimersByTime(250);
    let line = renderWidget(ui)[0];
    expect(SUBAGENT_SPINNER_FRAMES.some((frame) => line.includes(`${frame} web_search query…`))).toBe(true);
    expect(line).not.toContain("active");

    // Multiple distinct tools: one summary plus the count, never "3× same-tool".
    live.progress("r1", "read schema.ts…", { kind: "tool", status: "running" }, 3);
    vi.advanceTimersByTime(250);
    line = renderWidget(ui)[0];
    expect(SUBAGENT_SPINNER_FRAMES.some((frame) => line.includes(`${frame} read schema.ts… · 3 active`))).toBe(true);
    expect(line).not.toContain("3×");
    expect(line).not.toMatch(/3\s+web_search/);

    // All tools settled (0 active): suffix disappears.
    live.progress("r1", "read schema.ts done · working…", { kind: "tool", status: "completed" }, 0);
    vi.advanceTimersByTime(250);
    line = renderWidget(ui)[0];
    expect(line).toContain("✓ read schema.ts done · working…");
    expect(line).not.toContain("active");

    // An update without a tools payload leaves no stale count behind.
    live.progress("r1", "Writing response…");
    vi.advanceTimersByTime(250);
    line = renderWidget(ui)[0];
    expect(line).toContain("Writing response…");
    expect(line).not.toContain("active");
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

  test("background runtime shows a badge while running and leaves after settle", () => {
    const ui = createMockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { agent: "scout", startedAt: Date.now(), deadlineMs: 60_000, mode: "background", index: 1 });
    vi.advanceTimersByTime(250);

    let lines = renderWidget(ui);
    expect(lines[0]).toContain("⟨bg⟩");
    expect(lines[0]).toContain("scout");

    live.settle("r1", "completed");
    expect(lastWidgetContent(ui)).toBeUndefined();

    // Foreground runtimes carry no badge.
    live.track("r2", { agent: "worker", startedAt: Date.now(), deadlineMs: 60_000, mode: "foreground", index: 1 });
    vi.advanceTimersByTime(250);
    lines = renderWidget(ui);
    expect(lines.find((line) => line.includes("worker"))).not.toContain("⟨bg⟩");
  });
});
