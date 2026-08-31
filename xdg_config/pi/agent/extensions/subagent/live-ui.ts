/**
 * Live UI layer for active subagent runtimes.
 *
 * Data flow: sdk-executor onProgress summaries -> hub beginOperation wrapper ->
 * this controller -> ctx.ui.setWidget (above-editor panel showing one compact
 * overview line per runtime: agent, elapsed/remaining budget, current activity).
 * Background runtimes carry an ⟨bg⟩ badge while active. All runtimes leave the
 * panel immediately on settlement; terminal feedback belongs to the tool row
 * or background completion card.
 *
 * Every method is a safe no-op until attach(ui) provides a UI context, so
 * headless (-p) and RPC runs never touch terminal UI. Renders are throttled
 * (leading + trailing 250 ms), a 1 s heartbeat keeps elapsed/countdown fresh
 * while any runtime is tracked, and a 100 ms ticker advances the live spinner
 * while any runtime shows an active thinking/tool phase; all timers stop when
 * idle or disposed.
 */

import type { ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, type Component, type TUI } from "@earendil-works/pi-tui";

import type { SubagentActivityPhase } from "./protocol.ts";
import { SUBAGENT_DONE_GLYPH, SUBAGENT_FAILED_GLYPH, SUBAGENT_SPINNER_FRAMES } from "./protocol.ts";

/** Widget key used for the above-editor live panel. */
export const LIVE_WIDGET_ID = "subagent-live";

const THROTTLE_MS = 250;
const HEARTBEAT_MS = 1_000;
/** High-frequency repaint driving the live spinner while any phase is active. */
const SPINNER_TICK_MS = 100;

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
  /** Latest progress summary (thinking/toolcall/streaming wording from the executor). */
  activity?: string;
  /** Explicit thinking/tool boundary state driving the live affordance glyph. */
  activityPhase?: SubagentActivityPhase;
  /** Number of concurrently running tools in the latest progress update. */
  activeCount?: number;
}

/** Plain elapsed seconds count with unit suffix: `0s`, `42s`, `221s`. */
export function formatDuration(ms: number): string {
  return `${Math.max(0, Math.floor(ms / 1000))}s`;
}

/** Plain remaining seconds count, rounded up to avoid early expiry. */
function formatRemainingDuration(ms: number): string {
  return `${Math.max(0, Math.ceil(ms / 1000))}s`;
}

/** Render the current activity with the shared thinking/tool affordances. */
function renderActivity(theme: Theme, runtime: RuntimeDisplay, spinnerFrame: number): string {
  const summary = runtime.activity ?? "starting";
  const phase = runtime.activityPhase;
  let rendered: string;
  if (!phase) {
    rendered = summary;
  } else if (phase.kind === "thinking") {
    // While reasoning streams show a live spinner frame; once flushed the segment
    // is settled and matches the result renderer's completed `✓ Thinking` marker.
    rendered = phase.status === "completed"
      ? theme.fg("success", `${SUBAGENT_DONE_GLYPH} ${summary}`)
      : theme.fg("warning", `${SUBAGENT_SPINNER_FRAMES[spinnerFrame]} ${summary}`);
  } else {
    const glyph =
      phase.status === "failed" ? SUBAGENT_FAILED_GLYPH
      : phase.status === "completed" ? SUBAGENT_DONE_GLYPH
      : SUBAGENT_SPINNER_FRAMES[spinnerFrame];
    const color = phase.status === "failed" ? "error" : phase.status === "completed" ? "success" : "warning";
    rendered = theme.fg(color, `${glyph} ${summary}`);
  }
  // Concurrent tools (distinct toolCallIds) surface as a plain count suffix instead
  // of repeating one summary N times; 0/1 active stays concise and thinking stays
  // untouched (the executor reports an empty active set there).
  const activeSuffix = typeof runtime.activeCount === "number" && runtime.activeCount > 1
    ? theme.fg("muted", ` · ${runtime.activeCount} active`)
    : "";
  return rendered + activeSuffix;
}

function renderLines(
  theme: Theme,
  width: number,
  runtimes: ReadonlyMap<string, RuntimeDisplay>,
  now: number,
  spinnerFrame: number,
): string[] {
  const lines: string[] = [];
  for (const runtime of runtimes.values()) {
    const ref = `#${runtime.index}`;
    const badge = runtime.mode === "background" ? " ⟨bg⟩" : "";
    const elapsedMs = Math.max(0, now - runtime.startedAt);
    const remainingMs = runtime.startedAt + runtime.deadlineMs - now;
    const line =
      `${theme.fg("accent", "●")} ${theme.fg("muted", ref)} ${theme.bold(runtime.agent)}${theme.fg("muted", badge)} ` +
      theme.fg("muted", `· ${formatDuration(elapsedMs)} elapsed · ${formatRemainingDuration(remainingMs)} left ·`) +
      ` ${renderActivity(theme, runtime, spinnerFrame)}`;
    lines.push(truncateToWidth(line, width));
  }
  return lines;
}

export interface LiveUiController {
  /** Store the latest ctx.ui handle; all methods stay no-ops before this. */
  attach(ui: ExtensionUIContext): void;
  /** Register a runtime for display in the live panel. */
  track(runId: string, info: LiveRuntimeInfo): void;
  /**
   * Record a progress summary plus the optional live activity phase as the current
   * activity; activeCount is the number of concurrently running tools in this update.
   */
  progress(runId: string, summary: string, phase?: SubagentActivityPhase, activeCount?: number): void;
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
  let spinnerFrame = 0;
  let spinnerTimer: ReturnType<typeof setInterval> | undefined;

  // The component reads live controller state on every draw, so throttled
  // setWidget calls are pure repaint triggers.
  const widgetFactory = (_tui: TUI, theme: Theme): Component => ({
    render: (width: number) => renderLines(theme, width, runtimes, Date.now(), spinnerFrame),
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
    if (spinnerTimer !== undefined) {
      clearInterval(spinnerTimer);
      spinnerTimer = undefined;
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

  /** True while any tracked running runtime shows a live spinner phase. */
  const spinnerActive = (): boolean => {
    for (const runtime of runtimes.values()) {
      const phase = runtime.activityPhase;
      if (phase?.kind === "thinking" && phase.status === "running") return true;
      if (phase?.kind === "tool" && phase.status === "running") return true;
    }
    return false;
  };

  /** Start the spinner tick while a phase animates; stop it as soon as none does. */
  const syncSpinner = (): void => {
    if (disposed) return;
    if (spinnerActive()) {
      if (spinnerTimer === undefined) {
        spinnerTimer = setInterval(() => {
          spinnerFrame = (spinnerFrame + 1) % SUBAGENT_SPINNER_FRAMES.length;
          drawNow();
        }, SPINNER_TICK_MS);
      }
    } else if (spinnerTimer !== undefined) {
      clearInterval(spinnerTimer);
      spinnerTimer = undefined;
    }
  };

  const detach = (runId: string): void => {
    if (disposed || !runtimes.delete(runId)) return;
    stopHeartbeatIfIdle();
    syncSpinner();
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
      });
      ensureHeartbeat();
      syncSpinner();
      scheduleDraw();
    },
    progress(runId, summary, phase, activeCount) {
      const runtime = runtimes.get(runId);
      if (disposed || !runtime) return;
      runtime.activity = summary;
      runtime.activityPhase = phase;
      runtime.activeCount = activeCount;
      syncSpinner();
      scheduleDraw();
    },
    settle(runId, _outcome, _elapsedMs) {
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
