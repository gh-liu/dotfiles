/**
 * Live UI layer for active subagent runtimes.
 *
 * Data flow: sdk-executor onProgress summaries -> hub beginOperation wrapper ->
 * this controller -> ctx.ui.setWidget (a unified above-editor activity center
 * for every foreground and background runtime). Tool rows remain durable call
 * and result records; transient activity has exactly one visual owner here.
 * Settled background rows remain until Pi accepts the completion card; failed
 * delivery leaves a static recovery row rather than silently losing the result.
 *
 * Every method is a safe no-op until attach(ui) provides a UI context, so
 * headless (-p) and RPC runs never touch terminal UI. Renders are throttled
 * (leading + trailing 250 ms), a 1 s heartbeat keeps elapsed/deadline fresh
 * while any runtime is tracked, and a 250 ms ticker advances the job-level
 * spinner while any runtime is active; all timers stop when idle or disposed.
 */

import type { ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, wrapTextWithAnsi, type Component, type TUI } from "@earendil-works/pi-tui";

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
/** Repaint cadence for the job-level spinner while any runtime is active. */
const SPINNER_TICK_MS = 250;

export type LiveRuntimeMode = "foreground" | "background";

export interface LiveRuntimeInfo {
  /** Session-local short index (#N) for display. */
  index: number;
  agent: string;
  startedAt: number;
  deadlineMs: number;
  mode: LiveRuntimeMode;
  objective: string;
}

interface RuntimeDisplay {
  index: number;
  agent: string;
  startedAt: number;
  deadlineMs: number;
  mode: LiveRuntimeMode;
  objective: string;
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

/** Render current activity without duplicating the header's live spinner. */
function renderActivity(theme: Theme, runtime: RuntimeDisplay): string {
  const summary = runtime.activity ?? "starting";
  const phase = runtime.activityPhase;
  let rendered: string;
  if (!phase) {
    rendered = summary;
  } else if (phase.kind === "thinking") {
    rendered = phase.status === "completed"
      ? theme.fg("success", `${SUBAGENT_DONE_GLYPH} ${summary}`)
      : summary;
  } else {
    const glyph =
      phase.status === "failed" ? SUBAGENT_FAILED_GLYPH
      : phase.status === "completed" ? SUBAGENT_DONE_GLYPH
      : undefined;
    const color = phase.status === "failed" ? "error" : phase.status === "completed" ? "success" : "warning";
    rendered = glyph ? theme.fg(color, `${glyph} ${summary}`) : summary;
  }
  // Concurrent tools (distinct toolCallIds) surface as a plain count suffix instead
  // of repeating one summary N times; 0/1 active stays concise and thinking stays
  // untouched (the executor reports an empty active set there).
  const activeSuffix = typeof runtime.activeCount === "number" && runtime.activeCount > 1
    ? theme.fg("muted", ` · ${runtime.activeCount} active`)
    : "";
  return rendered + activeSuffix;
}

function objectiveLines(objective: string, width: number, maximumLines: number): string[] {
  const available = Math.max(1, width - 2);
  const limit = Math.min(maximumLines, width >= 80 ? 2 : 1);
  const wrapped = wrapTextWithAnsi(oneLine(objective, 500), available);
  const visible = wrapped.slice(0, limit);
  if (wrapped.length > visible.length && visible.length > 0) {
    visible[visible.length - 1] = truncateToWidth(`${visible[visible.length - 1]}…`, available, "…");
  }
  return visible;
}

function renderLines(
  theme: Theme,
  width: number,
  runtimes: ReadonlyMap<string, RuntimeDisplay>,
  now: number,
  spinnerFrame: number,
): string[] {
  const values = [...runtimes.values()];
  const active = values.filter((runtime) => !runtime.settlement).length;
  const reporting = runtimes.size - active;
  const needsInput = values.filter((runtime) => runtime.decision && !runtime.settlement).length;
  const counts = [`${active} active`, ...(needsInput ? [`${needsInput} needs input`] : []), ...(reporting ? [`${reporting} reporting`] : [])];
  const lines: string[] = [truncateToWidth(theme.fg("toolTitle", `Subagents · ${counts.join(" · ")}`), width)];
  const ordered = values.sort((first, second) => {
    const priority = (runtime: RuntimeDisplay) => runtime.decision ? 0 : runtime.settlement ? 2 : 1;
    return priority(first) - priority(second) || first.index - second.index;
  });
  const dense = ordered.length > 3;
  const visible = ordered.slice(0, 5);
  for (const runtime of visible) {
    const ref = `#${runtime.index}`;
    const elapsedMs = Math.max(0, now - runtime.startedAt);
    const time = width >= 52 ? `${formatDuration(elapsedMs)}/${formatDuration(runtime.deadlineMs)}` : formatDuration(elapsedMs);
    const identity = `${theme.fg("toolTitle", theme.bold(ref))} ${theme.bold(oneLine(runtime.agent, width < 45 ? 12 : 24))}`;
    let marker: string;
    let suffix = theme.fg("muted", ` · ${time}`);
    if (runtime.settlement === "report-failed") {
      marker = theme.fg("error", "!");
      suffix = theme.fg("error", " · reporting failed · use get");
    } else if (runtime.settlement === "reporting") {
      const outcome = runtime.outcome ?? "completed";
      marker = theme.fg(outcome === "completed" ? "success" : outcome === "failed" ? "error" : "warning",
        outcome === "completed" ? SUBAGENT_DONE_GLYPH : outcome === "failed" ? SUBAGENT_FAILED_GLYPH : "■");
      suffix = theme.fg("muted", ` · ${outcome} · reporting`);
    } else if (runtime.decision) {
      marker = theme.fg("warning", "!");
      suffix = theme.fg("warning", ` · needs input · ${formatDuration(elapsedMs)}`);
    } else {
      marker = theme.fg("warning", SUBAGENT_SPINNER_FRAMES[spinnerFrame] ?? SUBAGENT_SPINNER_FRAMES[0]);
    }
    lines.push(truncateToWidth(`${marker} ${identity}${suffix}`, width));
    if (!runtime.settlement) {
      for (const objective of objectiveLines(runtime.objective, width, dense ? 1 : 2)) {
        lines.push(truncateToWidth(theme.fg("dim", `  ${objective}`), width));
      }
      if (runtime.decision) {
        lines.push(truncateToWidth(theme.fg("warning", `  ! ${oneLine(runtime.decision, 500)}`), width));
      } else if (width >= 50 && !dense) {
        lines.push(truncateToWidth(`  ${theme.fg("muted", "↳")} ${renderActivity(theme, runtime)}`, width));
      }
    }
  }
  if (ordered.length > visible.length) {
    lines.push(truncateToWidth(theme.fg("muted", `… ${ordered.length - visible.length} more jobs · use get for details`), width));
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

  /** True while any tracked runtime is active, including startup and synthesis. */
  const spinnerActive = (): boolean => {
    for (const runtime of runtimes.values()) {
      if (!runtime.settlement && !runtime.decision) return true;
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
        objective: info.objective,
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
