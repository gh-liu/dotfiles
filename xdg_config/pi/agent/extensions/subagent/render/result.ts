import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

import { SUBAGENT_DONE_GLYPH, SUBAGENT_FAILED_GLYPH, SUBAGENT_SPINNER_GLYPH } from "../protocol.ts";
import { boundedLines, formatCountdown, oneLine, positiveSafeRuntimeIndex, publicRef, type SubagentRenderContext, type SubagentRenderResult } from "./shared.ts";

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
    const startedAt = typeof details.startedAt === "number" ? details.startedAt : undefined;
    const elapsed = startedAt === undefined ? "" : theme.fg("muted", ` · ${formatCountdown(Date.now() - startedAt)}`);
    const decision = details.needsDecision === true && details.decision && typeof details.decision === "object"
      ? details.decision as { question?: unknown }
      : undefined;
    const decisionQuestion = typeof decision?.question === "string" ? decision.question : undefined;
    const limit = options.expanded ? 12 : 8;
    const lines: string[] = [];
    let needsSpinner = false;
    if (options.expanded && timeline && timeline.length > 0) {
      const visibleTimeline = timeline.slice(-limit);
      const omitted = Math.max(0, timeline.length - visibleTimeline.length);
      if (omitted > 0) lines.push(theme.fg("dim", `… ${omitted} earlier events`));
      for (const entry of visibleTimeline) {
        lines.push(...timelineEntryLines(entry, theme));
      }
    } else if (options.expanded) {
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
      needsSpinner = true;
      lines.push(theme.fg("warning", `${FRAMES[context.state.spinnerFrame]} ${oneLine((item as { summary: string }).summary, 160)}…`) + elapsed);
    }
    // Unflushed thinking (phase running) always carries the live spinner, even
    // when earlier history is already present; flushed segments stay in the timeline.
    if (phase && phase.kind === "thinking" && phase.status === "running") {
      needsSpinner = true;
      lines.push(theme.fg("warning", `${FRAMES[context.state.spinnerFrame]} Thinking…`) + elapsed);
    }
    if (phase?.kind === "tool" && phase.status === "running" && active.length === 0 && progress) {
      needsSpinner = true;
      lines.push(theme.fg("warning", `${FRAMES[context.state.spinnerFrame]} ${oneLine(progress, 240)}`) + elapsed);
    }
    if (lines.length === 0 && phase?.status !== "running") {
      if (phase?.kind === "thinking") {
        lines.push(theme.fg("success", `${SUBAGENT_DONE_GLYPH} Thinking`));
      } else if (phase?.kind === "tool" && progress) {
        const failed = phase.status === "failed";
        lines.push(theme.fg(failed ? "error" : "success", `${failed ? SUBAGENT_FAILED_GLYPH : SUBAGENT_DONE_GLYPH} ${oneLine(progress, 240)}`));
      }
    }
    if (!phase && active.length === 0 && progress) {
      needsSpinner = true;
      lines.push(theme.fg("warning", `${FRAMES[context.state.spinnerFrame]} ${oneLine(progress, 240)}`) + elapsed);
    } else if (lines.length === 0) {
      needsSpinner = true;
      lines.push(theme.fg("warning", `${FRAMES[context.state.spinnerFrame]} Thinking…`));
    }
    if (decisionQuestion) {
      if (!options.expanded) lines.length = 0;
      lines.push(theme.fg("warning", `! needs input: ${oneLine(decisionQuestion, 200)}`) + elapsed);
      needsSpinner = false;
    }
    if (needsSpinner && !context.state.spinnerTimer) {
      context.state.spinnerTimer = setInterval(() => { context.state.spinnerFrame = ((context.state.spinnerFrame ?? 0) + 1) % FRAMES.length; context.invalidate(); }, 250);
      context.state.spinnerTimer.unref?.();
    } else if (!needsSpinner && context.state.spinnerTimer) {
      clearInterval(context.state.spinnerTimer);
      context.state.spinnerTimer = undefined;
    }
    return new Text(lines.join("\n"), 0, 0);
  }
  if (context.state.spinnerTimer) clearInterval(context.state.spinnerTimer);
  context.state.spinnerTimer = undefined;
  const status = typeof details.status === "string" ? details.status : undefined;
  const error = typeof details.error === "string" ? details.error : undefined;
  const handoff = details.handoff && typeof details.handoff === "object"
    ? details.handoff as Record<string, unknown>
    : undefined;
  const summary = typeof details.summary === "string"
    ? details.summary
    : typeof handoff?.summary === "string" ? handoff.summary : error;
  const displayRef = ref ?? publicRef(context.args.action === "run" ? undefined : context.args.jobId);
  if (context.args.action === "cancel") {
    const jobStatus = typeof details.status === "string" ? details.status : "unknown";
    const reference = displayRef ? ` · ${theme.fg("toolTitle", displayRef)}` : "";
    let text = context.isError && details.unknown !== true
      ? `${theme.fg("error", "✗ cancel request failed")}${reference}`
      : details.cancelled === true
        ? `${theme.fg("success", "✓ cancel acknowledged")}${reference}${theme.fg("muted", ` · ${jobStatus}`)}`
        : details.unknown === true || jobStatus === "unknown"
          ? theme.fg("warning", "? not cancelled · unknown/expired")
          : `${theme.fg("muted", "• not cancelled")}${reference}${theme.fg("muted", ` · ${jobStatus}`)}`;
    if (error) text += `\n${theme.fg("dim", oneLine(error, 240))}`;
    return new Text(text, 0, 0);
  }
  if (context.args.action === "get" && !context.args.jobId && Array.isArray(details.jobs)) {
    const jobs = details.jobs as Array<Record<string, unknown>>;
    const lines = jobs.slice(0, options.expanded ? 100 : 8).map((job) => {
      const jobRef = typeof job.ref === "string" ? job.ref : "?";
      const jobStatus = typeof job.status === "string" ? job.status : "unknown";
      const agent = typeof job.agent === "string" ? job.agent : "subagent";
      return `${theme.fg("toolTitle", jobRef)} ${agent} · ${jobStatus}`;
    });
    if (jobs.length > lines.length) lines.push(theme.fg("dim", `… ${jobs.length - lines.length} more jobs`));
    return new Text(lines.length ? lines.join("\n") : theme.fg("dim", "No subagent jobs."), 0, 0);
  }
  let text = status === "unknown" ? theme.fg("warning", "? unknown/expired")
    : context.args.action === "run" && context.args.background && status === "running" ? theme.fg("accent", "↗ tracking in Subagents")
    : context.isError || status === "failed" ? theme.fg("error", "✗ failed")
    : status === "running" ? theme.fg("warning", details.timedOut === true ? "● still running · wait expired" : "● running")
    : status === "interrupted" ? theme.fg("warning", "■ interrupted")
    : theme.fg("success", "✓ completed");
  if (typeof details.elapsedMs === "number") text += theme.fg("dim", ` · ${formatCountdown(details.elapsedMs)}`);
  if (summary && !options.expanded) text += `\n${theme.fg("dim", oneLine(summary, 240))}`;
  if (options.expanded) {
    if (summary) {
      text += `\n${theme.fg("toolTitle", "Summary")}`;
      for (const line of boundedLines(summary, 4_000, 20)) text += `\n${theme.fg("dim", `  ${line}`)}`;
    }
    const sections: Array<[string, unknown]> = [
      ["Changes", handoff?.changes ?? details.changes], ["Evidence", handoff?.evidence ?? details.evidence],
      ["Validation", handoff?.validation ?? details.validation], ["Risks", handoff?.risks ?? details.risks],
    ];
    for (const [label, value] of sections) {
      if (typeof value !== "string" || !value.trim()) continue;
      text += `\n${theme.fg("toolTitle", label)}`;
      for (const line of boundedLines(value, 4_000, 20)) text += `\n${theme.fg("dim", `  ${line}`)}`;
    }
    if (context.args.action === "get") {
      if (typeof details.activity === "string") text += `\n${theme.fg("toolTitle", "Current")}\n${theme.fg("dim", `  ${oneLine(details.activity, 240)}`)}`;
      if (Array.isArray(details.recentActivity) && details.recentActivity.length > 0) {
        text += `\n${theme.fg("toolTitle", "Recent activity")}`;
        for (const item of details.recentActivity.slice(-8)) if (typeof item === "string") text += `\n${theme.fg("dim", `  ${oneLine(item, 200)}`)}`;
      }
      if (details.workOrder && typeof details.workOrder === "object") {
        const workOrder = details.workOrder as Record<string, unknown>;
        text += `\n${theme.fg("toolTitle", "Work order")}`;
        for (const key of ["goal", "scope", "context", "constraints", "validation", "returnFormat"]) {
          const value = workOrder[key];
          if (typeof value === "string" && value) text += `\n${theme.fg("dim", `  ${key}: ${oneLine(value, 240)}`)}`;
          else if (Array.isArray(value) && value.length) text += `\n${theme.fg("dim", `  ${key}: ${oneLine(value.join("; "), 240)}`)}`;
        }
      }
    }
  }
  return new Text(text, 0, 0);
}
