/**
 * Live UI layer for active subagent runtimes.
 *
 * Data flow: sdk-executor onProgress summaries -> hub beginOperation wrapper ->
 * this controller -> ctx.ui.setWidget (above-editor panel showing one compact
 * overview line per background runtime: actionable ref, agent, elapsed/deadline,
 * and current activity). Foreground activity belongs to its tool row.
 * Settled background rows remain until Pi accepts the completion card; failed
 * delivery leaves a static recovery row rather than silently losing the result.
 *
 * Every method is a safe no-op until attach(ui) provides a UI context, so
 * headless (-p) and RPC runs never touch terminal UI. Renders are throttled
 * (leading + trailing 250 ms), a 1 s heartbeat keeps elapsed/deadline fresh
 * while any runtime is tracked, and a 250 ms ticker advances the live spinner
 * while any runtime shows an active thinking/tool phase; all timers stop when
 * idle or disposed.
 */

import type { ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, type Component, type TUI } from "@earendil-works/pi-tui";

import type { SubagentActivityPhase } from "./protocol.ts";
import { SUBAGENT_DONE_GLYPH, SUBAGENT_FAILED_GLYPH, SUBAGENT_SPINNER_FRAMES } from "./protocol.ts";

const oneLine = (text: string, maxCharacters: number): string => {
  const normalized = text.replace(/\s+/g, " ").trim();
  return normalized.length <= maxCharacters ? normalized : `${normalized.slice(0, Math.max(1, maxCharacters - 1))}…`;
};

/** Widget key used for the above-editor live panel. */
export const LIVE_WIDGET_ID = "subagent-live";

const THROTTLE_MS = 250;
const HEARTBEAT_MS = 1_000;
/** High-frequency repaint driving the live spinner while any phase is active. */
const SPINNER_TICK_MS = 250;

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
  decision?: string;
  settlement?: "reporting" | "report-failed";
  outcome?: "completed" | "failed" | "interrupted";
}

/** Plain elapsed seconds count with unit suffix: `0s`, `42s`, `221s`. */
export function formatDuration(ms: number): string {
  return `${Math.max(0, Math.floor(ms / 1000))}s`;
}

/** Render the current activity with the shared thinking/tool affordances. */
function renderActivity(theme: Theme, runtime: RuntimeDisplay, spinnerFrame: number): string {
  if (runtime.settlement === "report-failed") return theme.fg("error", "! settled · reporting failed · use get");
  if (runtime.settlement === "reporting") {
    const status = runtime.outcome ?? "completed";
    const glyph = status === "completed" ? SUBAGENT_DONE_GLYPH : status === "failed" ? SUBAGENT_FAILED_GLYPH : "■";
    return theme.fg(status === "completed" ? "success" : status === "failed" ? "error" : "warning", `${glyph} ${status} · reporting`);
  }
  if (runtime.decision) return theme.fg("warning", `! needs input: ${runtime.decision}`);
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
  if (runtimes.size > 1) lines.push(theme.fg("toolTitle", `Subagents (${runtimes.size})`));
  for (const runtime of runtimes.values()) {
    const ref = `#${runtime.index}`;
    const elapsedMs = Math.max(0, now - runtime.startedAt);
    const time = width >= 52 ? ` ${formatDuration(elapsedMs)}/${formatDuration(runtime.deadlineMs)}` : ` ${formatDuration(elapsedMs)}`;
    const identity = `${theme.bold(oneLine(runtime.agent, width < 45 ? 10 : 20))}${theme.fg("muted", time)}`;
    const activity = renderActivity(theme, runtime, spinnerFrame);
    const line = runtime.decision || runtime.settlement
      ? `${theme.fg("toolTitle", theme.bold(ref))} ${activity}${theme.fg("muted", ` · ${identity}`)}`
      : `${theme.fg("toolTitle", theme.bold(ref))} ${identity}  ${activity}`;
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
  progress(runId: string, summary: string, phase?: SubagentActivityPhase, activeCount?: number, decision?: string): void;
  /** Mark settlement while its completion card is handed to Pi. */
  settle(runId: string, outcome: "completed" | "failed" | "interrupted", elapsedMs?: number): void;
  /** Keep a settled recovery row when completion delivery fails. */
  reportFailed(runId: string): void;
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
    if (disposed || heartbeatTimer !== undefined || ![...runtimes.values()].some((runtime) => !runtime.settlement)) return;
    heartbeatTimer = setInterval(drawNow, HEARTBEAT_MS);
  };

  const syncHeartbeat = (): void => {
    if (![...runtimes.values()].some((runtime) => !runtime.settlement) && heartbeatTimer !== undefined) {
      clearInterval(heartbeatTimer);
      heartbeatTimer = undefined;
    }
  };

  /** True while any tracked running runtime shows a live spinner phase. */
  const spinnerActive = (): boolean => {
    for (const runtime of runtimes.values()) {
      if (runtime.settlement) continue;
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
    syncHeartbeat();
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
    progress(runId, summary, phase, activeCount, decision) {
      const runtime = runtimes.get(runId);
      if (disposed || !runtime) return;
      runtime.activity = summary;
      runtime.activityPhase = phase;
      runtime.activeCount = activeCount;
      runtime.decision = decision;
      syncSpinner();
      scheduleDraw();
    },
    settle(runId, outcome, _elapsedMs) {
      const runtime = runtimes.get(runId);
      if (disposed || !runtime) return;
      if (runtime.mode === "foreground") {
        detach(runId);
        return;
      }
      runtime.settlement = "reporting";
      runtime.outcome = outcome;
      runtime.decision = undefined;
      runtime.activeCount = undefined;
      syncHeartbeat();
      syncSpinner();
      scheduleDraw();
    },
    reportFailed(runId) {
      const runtime = runtimes.get(runId);
      if (disposed || !runtime) return;
      runtime.settlement = "report-failed";
      syncHeartbeat();
      syncSpinner();
      scheduleDraw();
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
