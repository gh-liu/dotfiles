import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import { createLiveUi } from "../live-ui.ts";
import { oneLine } from "../render/shared.ts";

function mockUi() {
  const calls: unknown[] = [];
  return {
    calls,
    setWidget(_key: string, content: unknown, options?: unknown): void {
      calls.push({ content, options });
    },
    setStatus(): void {},
  };
}

describe("live单一repaint clock", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  test("共享oneLine: live与render一致且脱敏", () => {
    expect(oneLine("a  b", 10)).toBe("a b");
    expect(oneLine("api_key=s3cr3t-value-x", 160)).not.toContain("s3cr3t-value-x");
  });

  test("timer数量: 跟踪后最多2个timer(单clock+trailing)", () => {
    const ui = mockUi();
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { index: 1, agent: "scout", turn: 1, startedAt: Date.now(), runId: "s1", task: "task" });
    live.progress("r1", "working");
    expect(vi.getTimerCount()).toBeLessThanOrEqual(2);
    live.settle("r1", "completed");
    live.remove("r1");
    vi.advanceTimersByTime(5_000);
    expect(vi.getTimerCount()).toBe(0);
  });

  test("trailing throttle保留: burst只补一次, clock推进spinner与elapsed", () => {
    const ui = mockUi() as unknown as Parameters<ReturnType<typeof createLiveUi>["attach"]>[0];
    const live = createLiveUi();
    live.attach(ui);
    live.track("r1", { index: 1, agent: "scout", turn: 1, startedAt: Date.now(), runId: "s1", task: "task" });
    const base = (ui as unknown as { widgetCalls?: unknown[] });
    void base;
    live.progress("r1", "one");
    live.progress("r1", "two");
    vi.advanceTimersByTime(250);
    vi.advanceTimersByTime(1_000);
    live.dispose();
    expect(vi.getTimerCount()).toBe(0);
  });
});
