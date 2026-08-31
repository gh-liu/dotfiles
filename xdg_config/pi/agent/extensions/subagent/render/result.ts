import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

import { boundedLines, formatCountdown, oneLine, positiveSafeRuntimeIndex, publicRef, type SubagentRenderContext, type SubagentRenderResult } from "./shared.ts";

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
    if (context.state.spinnerTimer) {
      clearInterval(context.state.spinnerTimer);
      context.state.spinnerTimer = undefined;
    }
    return new Text(theme.fg("muted", "↗ active in Subagents"), 0, 0);
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
