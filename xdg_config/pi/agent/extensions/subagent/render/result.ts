import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

import { boundedLines, formatDuration, oneLine, positiveSafeRuntimeIndex, publicRef, type SubagentRenderContext, type SubagentRenderResult } from "./shared.ts";

function renderActivity(details: Record<string, unknown>, theme: Theme): string {
  let text = "";
  const tools = details.toolProgress && typeof details.toolProgress === "object"
    ? details.toolProgress as Record<string, unknown>
    : undefined;
  const earlierCount = typeof tools?.earlierCount === "number" && tools.earlierCount > 0
    ? Math.floor(tools.earlierCount)
    : 0;
  if (earlierCount) text += `\n${theme.fg("muted", `… ${earlierCount} earlier tool ${earlierCount === 1 ? "activity" : "activities"}`)}`;
  const timeline = Array.isArray(details.timeline) ? details.timeline.slice(-24) : [];
  for (const entry of timeline) {
    if (!entry || typeof entry !== "object") continue;
    const item = entry as Record<string, unknown>;
    if (item.kind === "thinking") text += `\n${theme.fg("accent", "✓ Thinking")}`;
    else if (item.kind === "tool" && typeof item.summary === "string") {
      const failed = item.status === "failed";
      text += `\n${theme.fg(failed ? "error" : "success", failed ? "✗ failed" : "✓ completed")}${theme.fg("muted", `: ${oneLine(item.summary, 200)}`)}`;
    }
  }
  if (Array.isArray(tools?.active)) {
    for (const entry of tools.active) {
      if (!entry || typeof entry !== "object") continue;
      const item = entry as Record<string, unknown>;
      if (typeof item.summary === "string") {
        text += `\n${theme.fg("warning", "◷ running")}${theme.fg("muted", `: ${oneLine(item.summary, 200)}`)}`;
      }
    }
  }
  return text;
}

export function renderSubagentResult(
  result: SubagentRenderResult,
  options: { expanded: boolean; isPartial: boolean },
  theme: Theme,
  context: SubagentRenderContext,
): Text {
  const details = result.details && typeof result.details === "object" ? result.details as Record<string, unknown> : {};
  const ref = typeof details.ref === "string" ? publicRef(details.ref) : undefined;
  const index = positiveSafeRuntimeIndex(ref ? Number(ref.slice(1)) : details.displayIndex);
  if (index && !context.state.runtimeIndex) {
    context.state.runtimeIndex = index;
    context.state.ref = ref ?? `#${index}`;
    queueMicrotask(() => { try { context.invalidate(); } catch {} });
  }
  if (options.isPartial) {
    const activity = typeof details.activity === "string" ? details.activity : undefined;
    return new Text(`${theme.fg("accent", "● running")}${activity ? theme.fg("dim", ` · ${oneLine(activity, 240)}`) : ""}${renderActivity(details, theme)}`, 0, 0);
  }

  const status = typeof details.status === "string" ? details.status : "unknown";
  const turnStatus = typeof details.turnStatus === "string" ? details.turnStatus : undefined;
  const error = typeof details.error === "string" ? details.error : undefined;
  const summary = typeof details.summary === "string" ? details.summary : error;
  const displayRef = ref ?? ("ref" in context.args ? publicRef(context.args.ref) : undefined);

  if (status === "unknown" && error) {
    let text = theme.fg("error", "✗ subagent error");
    if (displayRef) text += theme.fg("toolTitle", ` · ${displayRef}`);
    text += `\n${theme.fg("dim", oneLine(error, 240))}`;
    return new Text(text, 0, 0);
  }

  if (context.args.action === "cancel" || context.args.action === "close") {
    const succeeded = context.args.action === "cancel" ? details.cancelled === true : details.closed === true;
    const label = succeeded ? `✓ ${context.args.action} acknowledged` : `• ${context.args.action} not applied`;
    let text = theme.fg(succeeded ? "success" : context.isError ? "error" : "muted", label);
    if (displayRef) text += theme.fg("toolTitle", ` · ${displayRef}`);
    text += theme.fg("muted", ` · ${status}`);
    if (error) text += `\n${theme.fg("dim", oneLine(error, 240))}`;
    return new Text(text, 0, 0);
  }

  if (context.args.action === "get" && !context.args.ref && Array.isArray(details.sessions)) {
    const sessions = details.sessions as Array<Record<string, unknown>>;
    const lines = sessions.slice(0, options.expanded ? 100 : 8).map((session) => {
      const sessionRef = typeof session.ref === "string" ? session.ref : "?";
      const sessionStatus = typeof session.status === "string" ? session.status : "unknown";
      const agent = typeof session.agent === "string" ? session.agent : "subagent";
      return `${theme.fg("toolTitle", sessionRef)} ${agent} · ${sessionStatus}`;
    });
    if (sessions.length > lines.length) lines.push(theme.fg("dim", `… ${sessions.length - lines.length} more sessions`));
    return new Text(lines.length ? lines.join("\n") : theme.fg("dim", "No subagent sessions."), 0, 0);
  }

  const agent = typeof details.agent === "string" ? details.agent : undefined;
  let text = status === "starting" || status === "running"
    ? theme.fg("warning", details.timedOut === true ? "● still running · wait expired" : "● running")
    : status === "idle" && turnStatus
      ? theme.fg(turnStatus === "failed" ? "error" : turnStatus === "interrupted" ? "warning" : "success",
          `${turnStatus === "completed" ? "✓" : turnStatus === "failed" ? "✗" : "■"}${displayRef ? ` ${displayRef}` : ""}${agent ? ` ${agent}` : ""}`)
      : status === "idle" ? theme.fg("success", `✓${displayRef ? ` ${displayRef}` : ""}${agent ? ` ${agent}` : ""} · session idle`)
      : status === "closed" ? theme.fg("muted", "× session closed")
      : status === "crashed" ? theme.fg("error", "✗ session crashed")
      : theme.fg("warning", "? unknown session");
  if (displayRef && !(status === "idle" && turnStatus)) text += theme.fg("toolTitle", ` · ${displayRef}`);
  if (typeof details.elapsedMs === "number") text += theme.fg("dim", ` · ${formatDuration(details.elapsedMs)}`);
  if (summary && !options.expanded) text += `\n${theme.fg("dim", oneLine(summary, 240))}`;
  if (options.expanded) {
    const sections: Array<[string, unknown]> = [
      ["Summary", summary], ["Changes", details.changes], ["Evidence", details.evidence],
      ["Validation", details.validation], ["Risks", details.risks],
    ];
    for (const [label, value] of sections) {
      if (typeof value !== "string" || !value.trim()) continue;
      text += `\n${theme.fg("toolTitle", label)}`;
      for (const line of boundedLines(value, 4_000, 20)) text += `\n${theme.fg("dim", `  ${line}`)}`;
    }
    if (context.args.action === "get" && typeof details.activity === "string") {
      text += `\n${theme.fg("toolTitle", "Current")}\n${theme.fg("dim", `  ${oneLine(details.activity, 240)}`)}`;
    }
    text += renderActivity(details, theme);
  }
  if (status === "idle" && displayRef) {
    text += `\n${theme.fg("muted", `${displayRef} · session open · follow-up or close`)}`;
  }
  return new Text(text, 0, 0);
}
