/**
 * Live UI layer for active subagent runtimes.
 *
 * Data flow: sdk-executor onProgress summaries -> hub beginOperation wrapper ->
 * this controller -> ctx.ui.setWidget (an above-editor activity center for
 * background operations whose tool call has already returned). Foreground
 * activity stays in its tool result. Settled rows remain until the matching
 * completion card starts rendering; failed
 * delivery leaves a static recovery row rather than silently losing the result.
 *
 * Every method is a safe no-op until attach(ui) provides a UI context, so
 * headless (-p) and RPC runs never touch terminal UI. Renders are throttled
 * (leading + trailing 250 ms) and a single 250 ms repaint clock keeps elapsed
 * time fresh and advances the job-level spinner while any runtime is tracked;
 * all timers stop when idle or disposed.
 */

import type { ExtensionUIContext, Theme } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, wrapTextWithAnsi, type Component, type TUI } from "@earendil-works/pi-tui";

import type { SubagentActivityPhase } from "./protocol.ts";
import { SUBAGENT_DONE_GLYPH, SUBAGENT_FAILED_GLYPH, SUBAGENT_SPINNER_FRAMES } from "./protocol.ts";
import { oneLine, renderToolSummary } from "./render/shared.ts";

/** Widget key used for the above-editor live panel. */
export const LIVE_WIDGET_ID = "subagent-live";

const THROTTLE_MS = 250;
/** Single repaint clock: elapsed freshness + job-level spinner. Trailing throttle stays separate. */
const REPAINT_TICK_MS = 250;

export interface LiveRuntimeInfo {
  /** Session-local short index (#N) for display. */
  index: number;
  agent: string;
  turn: number;
  startedAt: number;
  /** Internal runtime identity, used only to remove all rows when a session closes. */
  runId: string;
  task: string;
}

interface RuntimeDisplay {
  index: number;
  agent: string;
  turn: number;
  startedAt: number;
  runId: string;
  task: string;
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
    const status = glyph ? `${theme.fg(color, glyph)} ` : "";
    rendered = `${status}${renderToolSummary(theme, summary)}`;
  }
  // Concurrent tools (distinct toolCallIds) surface as a plain count suffix instead
  // of repeating one summary N times; 0/1 active stays concise and thinking stays
  // untouched (the executor reports an empty active set there).
  const activeSuffix = typeof runtime.activeCount === "number" && runtime.activeCount > 1
    ? theme.fg("muted", ` · ${runtime.activeCount} active`)
    : "";
  return rendered + activeSuffix;
}

function taskLines(task: string, width: number, maximumLines: number): string[] {
  const available = Math.max(1, width - 2);
  const limit = Math.min(maximumLines, width >= 80 ? 2 : 1);
  const wrapped = wrapTextWithAnsi(oneLine(task, 500), available);
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
  const lines: string[] = [truncateToWidth(theme.fg("toolTitle", `Background subagents · ${counts.join(" · ")}`), width)];
  const ordered = values.sort((first, second) => {
    const priority = (runtime: RuntimeDisplay) => runtime.decision ? 0 : runtime.settlement ? 2 : 1;
    return priority(first) - priority(second) || first.index - second.index;
  });
  const dense = ordered.length > 3;
  const visible = ordered.slice(0, 5);
  for (const runtime of visible) {
    const ref = `#${runtime.index}`;
    const elapsedMs = Math.max(0, now - runtime.startedAt);
    const time = formatDuration(elapsedMs);
    const turn = width >= 45 ? theme.fg("muted", ` · turn ${runtime.turn}`) : "";
    const identity = `${theme.fg("toolTitle", theme.bold(ref))} ${theme.bold(oneLine(runtime.agent, width < 45 ? 12 : 24))}${turn}`;
    let marker: string;
    let suffix = theme.fg("muted", ` · ${time}`);
    if (runtime.settlement === "report-failed") {
      marker = theme.fg("error", "!");
      suffix = theme.fg("error", ` · card failed · get ${ref}`);
    } else if (runtime.settlement === "reporting") {
      const outcome = runtime.outcome ?? "completed";
      marker = theme.fg(outcome === "completed" ? "success" : outcome === "failed" ? "error" : "warning",
        outcome === "completed" ? SUBAGENT_DONE_GLYPH : outcome === "failed" ? SUBAGENT_FAILED_GLYPH : "■");
      suffix = theme.fg("muted", ` · result ready · awaiting card · get ${ref}`);
    } else if (runtime.decision) {
      marker = theme.fg("warning", "!");
      suffix = theme.fg("warning", ` · needs input · ${formatDuration(elapsedMs)}`);
    } else {
      marker = theme.fg("warning", SUBAGENT_SPINNER_FRAMES[spinnerFrame] ?? SUBAGENT_SPINNER_FRAMES[0]);
    }
    lines.push(truncateToWidth(`${marker} ${identity}${suffix}`, width));
    if (!runtime.settlement) {
      for (const task of taskLines(runtime.task, width, dense ? 1 : 2)) {
        lines.push(truncateToWidth(theme.fg("dim", `  ${task}`), width));
      }
      if (runtime.decision) {
        lines.push(truncateToWidth(theme.fg("warning", `  ! ${oneLine(runtime.decision, 500)}`), width));
      } else if (width >= 50 && !dense) {
        lines.push(truncateToWidth(`  ${theme.fg("muted", "↳")} ${renderActivity(theme, runtime)}`, width));
      }
    }
  }
  if (ordered.length > visible.length) {
    lines.push(truncateToWidth(theme.fg("muted", `… ${ordered.length - visible.length} more sessions · use get for details`), width));
  }
  return lines;
}

export interface LiveUiController {
  /** Store the latest ctx.ui handle; all methods stay no-ops before this. */
  attach(ui: ExtensionUIContext): void;
  /** Register an accepted background operation for display in the live panel. */
  track(operationKey: string, info: LiveRuntimeInfo): void;
  /**
   * Record a progress summary plus the optional live activity phase as the current
   * activity; activeCount is the number of concurrently running tools in this update.
   */
  progress(operationKey: string, summary: string, phase?: SubagentActivityPhase, activeCount?: number, decision?: string): void;
  /** Mark settlement while its completion card is handed to Pi. */
  settle(operationKey: string, outcome: "completed" | "failed" | "interrupted", elapsedMs?: number): void;
  /** Keep a settled recovery row when completion delivery fails. */
  reportFailed(operationKey: string): void;
  /** Remove one operation after its completion card starts rendering. */
  remove(operationKey: string): void;
  /** Idempotently remove every operation owned by a closed/crashed session. */
  removeSession(runId: string): void;
  /** Clear the widget and stop all timers. */
  dispose(): void;
}

export function createLiveUi(): LiveUiController {
  let ui: ExtensionUIContext | undefined;
  let disposed = false;
  const runtimes = new Map<string, RuntimeDisplay>();
  let lastRenderAt = Number.NEGATIVE_INFINITY;
  let trailingTimer: ReturnType<typeof setTimeout> | undefined;
  let repaintTimer: ReturnType<typeof setInterval> | undefined;
  let spinnerFrame = 0;

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
    if (repaintTimer !== undefined) {
      clearInterval(repaintTimer);
      repaintTimer = undefined;
    }
  };

  /** True while any tracked runtime is active, including startup and synthesis. */
  const spinnerActive = (): boolean => {
    for (const runtime of runtimes.values()) {
      if (!runtime.settlement && !runtime.decision) return true;
    }
    return false;
  };

  /** Single repaint clock: heartbeat freshness + spinner advance. Stops when idle. */
  const syncRepaintClock = (): void => {
    if (disposed) return;
    if (runtimes.size === 0) {
      if (repaintTimer !== undefined) {
        clearInterval(repaintTimer);
        repaintTimer = undefined;
      }
      return;
    }
    if (repaintTimer !== undefined) return;
    repaintTimer = setInterval(() => {
      if (spinnerActive()) spinnerFrame = (spinnerFrame + 1) % SUBAGENT_SPINNER_FRAMES.length;
      drawNow();
    }, REPAINT_TICK_MS);
  };

  const detach = (operationKey: string): void => {
    if (disposed || !runtimes.delete(operationKey)) return;
    syncRepaintClock();
    // Clear immediately when the panel becomes empty; otherwise coalesce.
    if (runtimes.size === 0) drawNow();
    else scheduleDraw();
  };

  return {
    attach(nextUi) {
      if (disposed) return;
      ui = nextUi;
    },
    track(operationKey, info) {
      if (disposed) return;
      runtimes.set(operationKey, {
        index: info.index,
        agent: info.agent,
        turn: info.turn,
        startedAt: info.startedAt,
        runId: info.runId,
        task: info.task,
      });
      syncRepaintClock();
      scheduleDraw();
    },
    progress(operationKey, summary, phase, activeCount, decision) {
      const runtime = runtimes.get(operationKey);
      if (disposed || !runtime) return;
      runtime.activity = summary;
      runtime.activityPhase = phase;
      runtime.activeCount = activeCount;
      runtime.decision = decision;
      syncRepaintClock();
      scheduleDraw();
    },
    settle(operationKey, outcome, _elapsedMs) {
      const runtime = runtimes.get(operationKey);
      if (disposed || !runtime) return;
      runtime.settlement = "reporting";
      runtime.outcome = outcome;
      runtime.decision = undefined;
      runtime.activeCount = undefined;
      syncRepaintClock();
      scheduleDraw();
    },
    reportFailed(operationKey) {
      const runtime = runtimes.get(operationKey);
      if (disposed || !runtime) return;
      runtime.settlement = "report-failed";
      syncRepaintClock();
      scheduleDraw();
    },
    remove(operationKey) {
      detach(operationKey);
    },
    removeSession(runId) {
      if (disposed) return;
      const keys = [...runtimes.entries()]
        .filter(([, runtime]) => runtime.runId === runId)
        .map(([operationKey]) => operationKey);
      for (const operationKey of keys) runtimes.delete(operationKey);
      if (keys.length === 0) return;
      syncRepaintClock();
      if (runtimes.size === 0) drawNow();
      else scheduleDraw();
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
