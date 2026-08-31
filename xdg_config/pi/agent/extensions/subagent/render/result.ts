import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

import { SUBAGENT_DONE_GLYPH, SUBAGENT_FAILED_GLYPH, SUBAGENT_SPINNER_GLYPH } from "../protocol.ts";
import { formatCountdown, oneLine, positiveSafeRuntimeIndex, type SubagentRenderContext, type SubagentRenderResult } from "./shared.ts";

const FRAMES = [SUBAGENT_SPINNER_GLYPH, "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

/** Render one interleaved timeline entry (tool call or thinking segment) as lines. */
function timelineEntryLines(entry: unknown, theme: Theme): string[] {
  if (!entry || typeof entry !== "object") return [];
  const typed = entry as { kind?: unknown; summary?: unknown; status?: unknown; text?: unknown };
  if (typed.kind === "thinking") {
    // Keep the timeline entry for ordering/observability, but never render the
    // reasoning text to the UI — show only a generic marker to avoid leaking/noise.
    if (typeof typed.text !== "string" || !typed.text.trim()) return [];
    // Thinking only reaches the timeline once the executor flushes it (before a
    // tool call or at message end), so a timeline thinking entry is always ended:
    // show the static completed icon. In-progress, unflushed thinking has no
    // timeline entry and is represented by the fallback spinner instead.
    return [theme.fg("success", `${SUBAGENT_DONE_GLYPH} Thinking`)];
  }
  if (typed.kind === "tool" && typeof typed.summary === "string") {
    return [theme.fg(typed.status === "failed" ? "error" : "success", `${typed.status === "failed" ? SUBAGENT_FAILED_GLYPH : SUBAGENT_DONE_GLYPH} ${oneLine(typed.summary, 160)}`)];
  }
  return [];
}

export function renderSubagentResult(result: SubagentRenderResult, options: { expanded: boolean; isPartial: boolean }, theme: Theme, context: SubagentRenderContext): Text {
  const details = result.details && typeof result.details === "object" ? result.details as Record<string, unknown> : {};
  const ref = typeof details.ref === "string" && /^#[1-9]\d*$/.test(details.ref) ? details.ref : undefined;
  const index = positiveSafeRuntimeIndex(ref ? Number(ref.slice(1)) : details.displayIndex);
  if (index && !context.state.runtimeIndex) {
    context.state.runtimeIndex = index;
    context.state.ref = ref ?? `#${index}`;
    queueMicrotask(() => { try { context.invalidate(); } catch {} });
  }
  if (options.isPartial) {
    context.state.spinnerFrame ??= 0;
    if (!context.state.spinnerTimer) {
      context.state.spinnerTimer = setInterval(() => { context.state.spinnerFrame = ((context.state.spinnerFrame ?? 0) + 1) % FRAMES.length; context.invalidate(); }, 80);
      context.state.spinnerTimer.unref?.();
    }
    const progress = result.content.find((part) => part.type === "text")?.text;
    const toolProgress = details.toolProgress && typeof details.toolProgress === "object"
      ? details.toolProgress as { earlierCount?: unknown; history?: unknown; active?: unknown }
      : undefined;
    const history = Array.isArray(toolProgress?.history) ? toolProgress.history : [];
    const active = Array.isArray(toolProgress?.active) ? toolProgress.active : [];
    const rawTimeline = details.timeline;
    const timeline = Array.isArray(rawTimeline) ? rawTimeline : undefined;
    const rawPhase = details.phase;
    const phase = rawPhase && typeof rawPhase === "object"
      ? rawPhase as { kind?: unknown; status?: unknown }
      : undefined;
    const limit = options.expanded ? 12 : 8;
    const lines: string[] = [];
    if (timeline && timeline.length > 0) {
      const visibleTimeline = timeline.slice(-limit);
      const omitted = Math.max(0, timeline.length - visibleTimeline.length);
      if (omitted > 0) lines.push(theme.fg("dim", `… ${omitted} earlier events`));
      for (const entry of visibleTimeline) {
        lines.push(...timelineEntryLines(entry, theme));
      }
    } else {
      const visibleHistory = history.slice(-limit);
      const omitted = (typeof toolProgress?.earlierCount === "number" ? toolProgress.earlierCount : 0) + Math.max(0, history.length - visibleHistory.length);
      if (omitted > 0) lines.push(theme.fg("dim", `… ${omitted} earlier calls`));
      for (const item of visibleHistory) {
        if (!item || typeof item !== "object") continue;
        const typed = item as { summary?: unknown; status?: unknown };
        if (typeof typed.summary !== "string") continue;
        lines.push(theme.fg(typed.status === "failed" ? "error" : "success", `${typed.status === "failed" ? "✗" : "✓"} ${oneLine(typed.summary, 160)}`));
      }
    }
    for (const item of active) {
      if (!item || typeof item !== "object" || typeof (item as { summary?: unknown }).summary !== "string") continue;
      lines.push(theme.fg("warning", `${FRAMES[context.state.spinnerFrame]} ${oneLine((item as { summary: string }).summary, 160)}…`));
    }
    // Unflushed thinking (phase running) always carries the live spinner, even
    // when earlier history is already present; flushed segments stay in the timeline.
    if (phase && phase.kind === "thinking" && phase.status === "running") {
      lines.push(theme.fg("warning", `${FRAMES[context.state.spinnerFrame]} Thinking…`));
    }
    if (lines.length === 0) lines.push(theme.fg("warning", `${FRAMES[context.state.spinnerFrame]} Thinking…`) + (progress ? theme.fg("dim", ` — ${oneLine(progress, 240)}`) : ""));
    return new Text(lines.join("\n"), 0, 0);
  }
  if (context.state.spinnerTimer) clearInterval(context.state.spinnerTimer);
  context.state.spinnerTimer = undefined;
  const status = typeof details.status === "string" ? details.status : undefined;
  const error = typeof details.error === "string" ? details.error : undefined;
  const summary = typeof details.summary === "string" ? details.summary : error;
  let text = context.isError || status === "failed" ? theme.fg("error", "✗ failed")
    : status === "running" ? theme.fg("warning", "● running")
    : status === "interrupted" ? theme.fg("warning", "■ interrupted")
    : context.args.action === "cancel" ? theme.fg("warning", details.cancelled === true ? "■ cancelled" : "• already terminal")
    : theme.fg("success", "✓ completed");
  if (typeof details.elapsedMs === "number") text += theme.fg("dim", ` · ${formatCountdown(details.elapsedMs)}`);
  if (summary) text += options.expanded ? `\n${summary.split("\n").slice(0, 20).map((line) => theme.fg("dim", line)).join("\n")}` : `\n${theme.fg("dim", oneLine(summary, 240))}`;
  return new Text(text, 0, 0);
}
