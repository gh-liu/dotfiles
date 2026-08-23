/**
 * Live UI layer for active subagent runtimes.
 *
 * Data flow: sdk-executor onProgress summaries -> hub beginOperation wrapper ->
 * this controller -> ctx.ui.setWidget (above-editor panel showing one compact
 * overview line per runtime: agent, elapsed/remaining budget, current activity).
 * Background (`start`) runtimes carry an ⟨bg⟩ badge and stay visible as a dim
 * idle line after their operation settles until they are closed.
 *
 * Every method is a safe no-op until attach(ui) provides a UI context, so
 * headless (-p) and RPC runs never touch terminal UI. Renders are throttled
 * (leading + trailing 250 ms) and a 1 s heartbeat keeps elapsed/countdown
 * fresh while any runtime is tracked; all timers stop when idle or disposed.
 */

import type { ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, type Component, type TUI } from "@earendil-works/pi-tui";

/** Widget key used for the above-editor live panel. */
export const LIVE_WIDGET_ID = "subagent-live";

const THROTTLE_MS = 250;
const HEARTBEAT_MS = 1_000;

export type LiveRuntimeMode = "foreground" | "background";

export interface LiveRuntimeInfo {
  /** Session-local short index (#N) for display. */
  index: number;
  agent: string;
  startedAt: number;
  deadlineMs: number;
  mode: LiveRuntimeMode;
}

interface RuntimeDisplay {
  index: number;
  agent: string;
  startedAt: number;
  deadlineMs: number;
  mode: LiveRuntimeMode;
  /** "running" while an operation is active; background runtimes turn "idle" after settling. */
  phase: "running" | "idle";
  /** Latest progress summary (thinking/toolcall/streaming wording from the executor). */
  activity?: string;
}

/** Plain elapsed seconds count with unit suffix: `0s`, `42s`, `221s`. */
export function formatDuration(ms: number): string {
  return `${Math.max(0, Math.floor(ms / 1000))}s`;
}

/** Plain remaining seconds count, rounded up to avoid early expiry. */
function formatRemainingDuration(ms: number): string {
  return `${Math.max(0, Math.ceil(ms / 1000))}s`;
}

function renderLines(
  theme: Theme,
  width: number,
  runtimes: ReadonlyMap<string, RuntimeDisplay>,
  now: number,
): string[] {
  const lines: string[] = [];
  for (const runtime of runtimes.values()) {
    const ref = `#${runtime.index}`;
    const badge = runtime.mode === "background" ? " ⟨bg⟩" : "";
    if (runtime.phase === "idle") {
      // Background runtime settled but still open: dim reminder that it holds a slot.
      lines.push(truncateToWidth(theme.fg("dim", `○ ${ref} ${runtime.agent}${badge} · idle · holds slot`), width));
      continue;
    }
    const elapsedMs = Math.max(0, now - runtime.startedAt);
    const remainingMs = runtime.startedAt + runtime.deadlineMs - now;
    const line =
      `${theme.fg("accent", "●")} ${theme.fg("muted", ref)} ${theme.bold(runtime.agent)}${theme.fg("muted", badge)} ` +
      theme.fg("muted", `· ${formatDuration(elapsedMs)} / ${formatRemainingDuration(remainingMs)} ·`) +
      ` ${runtime.activity ?? "starting"}`;
    lines.push(truncateToWidth(line, width));
  }
  return lines;
}

export interface LiveUiController {
  /** Store the latest ctx.ui handle; all methods stay no-ops before this. */
  attach(ui: ExtensionUIContext): void;
  /** Register a runtime for display in the live panel. */
  track(runId: string, info: LiveRuntimeInfo): void;
  /** Record a progress summary as the runtime's current activity. */
  progress(runId: string, summary: string): void;
  /** Idempotently remove a settled runtime from the panel. */
  settle(runId: string, outcome: "completed" | "failed" | "interrupted", elapsedMs?: number): void;
  /** Idempotently force-remove a runtime (close/crash/shutdown). */
  remove(runId: string): void;
  /** Clear the widget and stop all timers. */
  dispose(): void;
}

export function createLiveUi(): LiveUiController {
  let ui: ExtensionUIContext | undefined;
  let disposed = false;
  const runtimes = new Map<string, RuntimeDisplay>();
  let lastRenderAt = Number.NEGATIVE_INFINITY;
  let trailingTimer: ReturnType<typeof setTimeout> | undefined;
  let heartbeatTimer: ReturnType<typeof setInterval> | undefined;

  // The component reads live controller state on every draw, so throttled
  // setWidget calls are pure repaint triggers.
  const widgetFactory = (_tui: TUI, theme: Theme): Component => ({
    render: (width: number) => renderLines(theme, width, runtimes, Date.now()),
    invalidate: () => {},
  });

  const drawNow = (): void => {
    if (!ui || disposed) return;
    lastRenderAt = Date.now();
    if (trailingTimer !== undefined) {
      clearTimeout(trailingTimer);
      trailingTimer = undefined;
    }
    if (runtimes.size === 0) ui.setWidget(LIVE_WIDGET_ID, undefined);
    else ui.setWidget(LIVE_WIDGET_ID, widgetFactory, { placement: "aboveEditor" });
  };

  const scheduleDraw = (): void => {
    if (!ui || disposed) return;
    const waitMs = THROTTLE_MS - (Date.now() - lastRenderAt);
    if (waitMs <= 0) {
      drawNow();
      return;
    }
    if (trailingTimer === undefined) {
      trailingTimer = setTimeout(() => {
        trailingTimer = undefined;
        drawNow();
      }, waitMs);
    }
  };

  const stopTimers = (): void => {
    if (trailingTimer !== undefined) {
      clearTimeout(trailingTimer);
      trailingTimer = undefined;
    }
    if (heartbeatTimer !== undefined) {
      clearInterval(heartbeatTimer);
      heartbeatTimer = undefined;
    }
  };

  const ensureHeartbeat = (): void => {
    if (disposed || heartbeatTimer !== undefined || runtimes.size === 0) return;
    heartbeatTimer = setInterval(drawNow, HEARTBEAT_MS);
  };

  const stopHeartbeatIfIdle = (): void => {
    if (runtimes.size === 0 && heartbeatTimer !== undefined) {
      clearInterval(heartbeatTimer);
      heartbeatTimer = undefined;
    }
  };

  const detach = (runId: string): void => {
    if (disposed || !runtimes.delete(runId)) return;
    stopHeartbeatIfIdle();
    // Clear immediately when the panel becomes empty; otherwise coalesce.
    if (runtimes.size === 0) drawNow();
    else scheduleDraw();
  };

  return {
    attach(nextUi) {
      if (disposed) return;
      ui = nextUi;
    },
    track(runId, info) {
      if (disposed) return;
      runtimes.set(runId, {
        index: info.index,
        agent: info.agent,
        startedAt: info.startedAt,
        deadlineMs: info.deadlineMs,
        mode: info.mode,
        phase: "running",
      });
      ensureHeartbeat();
      scheduleDraw();
    },
    progress(runId, summary) {
      const runtime = runtimes.get(runId);
      if (disposed || !runtime) return;
      runtime.activity = summary;
      scheduleDraw();
    },
    settle(runId, _outcome, _elapsedMs) {
      // Outcome and elapsed are accepted for future polish. Foreground runtimes
      // leave the panel immediately; background ones stay visible as a dim idle
      // line because they keep holding a capacity slot until closed.
      const runtime = runtimes.get(runId);
      if (disposed || !runtime) return;
      if (runtime.mode === "background") {
        runtime.phase = "idle";
        scheduleDraw();
        return;
      }
      detach(runId);
    },
    remove(runId) {
      detach(runId);
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      stopTimers();
      if (ui) ui.setWidget(LIVE_WIDGET_ID, undefined);
      runtimes.clear();
    },
  };
}
