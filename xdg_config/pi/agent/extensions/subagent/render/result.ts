import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

import { boundedLines, formatCountdown, oneLine, positiveSafeRuntimeIndex, publicRef, type SubagentRenderContext, type SubagentRenderResult } from "./shared.ts";

function renderTimeline(details: Record<string, unknown>, theme: Theme): string {
  if (!Array.isArray(details.timeline) || details.timeline.length === 0) return "";
  let text = "";
  for (const entry of details.timeline.slice(-24)) {
    if (!entry || typeof entry !== "object") continue;
    const item = entry as Record<string, unknown>;
    if (item.kind === "thinking") {
      text += `\n${theme.fg("accent", "✓ Thinking")}`;
    } else if (item.kind === "tool" && typeof item.summary === "string") {
      const status = item.status === "failed"
        ? { label: "✗ failed", color: "error" as const }
        : item.status === "completed"
          ? { label: "✓ completed", color: "success" as const }
          : { label: "● running", color: "warning" as const };
      text += `\n${theme.fg(status.color, status.label)}${theme.fg("muted", `: ${oneLine(item.summary, 200)}`)}`;
    }
  }
  return text;
}

export function renderSubagentResult(result: SubagentRenderResult, options: { expanded: boolean; isPartial: boolean }, theme: Theme, context: SubagentRenderContext): Text {
  const details = result.details && typeof result.details === "object" ? result.details as Record<string, unknown> : {};
  const ref = typeof details.ref === "string" && /^#[1-9]\d*$/.test(details.ref) ? details.ref : undefined;
  const workflowRef = typeof details.ref === "string" && /^W#[1-9]\d*$/.test(details.ref) ? details.ref : undefined;
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
    if (!options.expanded) {
      return new Text(theme.fg("muted", context.args.action === "workflow" ? "↗ active workflow in Subagents" : "↗ active in Subagents"), 0, 0);
    }
    const activity = typeof details.activity === "string" ? details.activity : undefined;
    let text = `${theme.fg("accent", "● running")}${activity ? theme.fg("dim", ` · ${oneLine(activity, 240)}`) : ""}`;
    text += renderTimeline(details, theme);
    return new Text(text, 0, 0);
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
  const displayRef = ref ?? workflowRef ?? publicRef(context.args.action === "run" || context.args.action === "workflow" ? undefined : context.args.jobId);
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
    if (Array.isArray(details.workflows)) {
      for (const workflow of (details.workflows as Array<Record<string, unknown>>).slice(0, options.expanded ? 100 : 8)) {
        const workflowRef = typeof workflow.ref === "string" ? workflow.ref : "?";
        const workflowStatus = typeof workflow.status === "string" ? workflow.status : "unknown";
        const nodeCount = Array.isArray(workflow.nodes) ? workflow.nodes.length : 0;
        lines.push(`${theme.fg("toolTitle", workflowRef)} workflow · ${workflowStatus} · ${nodeCount} nodes`);
      }
    }
    return new Text(lines.length ? lines.join("\n") : theme.fg("dim", "No subagent jobs or workflows."), 0, 0);
  }
  if (context.args.action === "workflow" || workflowRef || Array.isArray(details.nodes)) {
    const nodes = Array.isArray(details.nodes) ? details.nodes as Array<Record<string, unknown>> : [];
    const completed = nodes.filter((node) => node.status === "completed").length;
    let text = status === "running" ? theme.fg("accent", "↗ workflow running")
      : status === "completed" ? theme.fg("success", "✓ workflow completed")
      : status === "interrupted" ? theme.fg("warning", "■ workflow interrupted")
      : theme.fg("error", "✗ workflow failed");
    if (displayRef) text += theme.fg("toolTitle", ` · ${displayRef}`);
    if (nodes.length) text += theme.fg("muted", ` · ${completed}/${nodes.length} nodes`);
    const visible = options.expanded ? nodes.slice(0, 20) : nodes.filter((node) => node.status !== "completed").slice(0, 5);
    for (const node of visible) {
      const nodeStatus = typeof node.status === "string" ? node.status : "unknown";
      const marker = nodeStatus === "completed" ? "✓" : nodeStatus === "running" ? "●" : nodeStatus === "pending" ? "○" : nodeStatus === "skipped" ? "−" : "✗";
      const nodeId = typeof node.id === "string" ? node.id : "node";
      const agent = typeof node.agent === "string" ? node.agent : "subagent";
      text += `\n${theme.fg(nodeStatus === "completed" ? "success" : nodeStatus === "failed" ? "error" : "muted", `  ${marker}`)} ${theme.fg("toolTitle", nodeId)} ${theme.fg("dim", `· ${agent} · ${nodeStatus}`)}`;
      if (options.expanded && typeof node.objective === "string") text += `\n${theme.fg("dim", `    ${oneLine(node.objective, 240)}`)}`;
      if (options.expanded && typeof node.error === "string") text += `\n${theme.fg("error", `    ${oneLine(node.error, 240)}`)}`;
    }
    if (!options.expanded && completed === nodes.length && nodes.length > 0) text += `\n${theme.fg("dim", "  All nodes completed")}`;
    return new Text(text, 0, 0);
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
    text += renderTimeline(details, theme);
  }
  return new Text(text, 0, 0);
}
