import { type Theme } from "@earendil-works/pi-coding-agent";
import { type Component, Text } from "@earendil-works/pi-tui";

import { boundedLines, formatDuration, oneLine, positiveSafeRuntimeIndex, publicRef, renderActivityRow, renderDetailSections, renderPartitionedStatus, renderToolSummary, type SubagentRenderContext, type SubagentRenderResult } from "./shared.ts";

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
    if (item.kind === "thinking") text += `\n${renderActivityRow("✓ Thinking", theme)}`;
    else if (item.kind === "tool" && typeof item.summary === "string") {
      text += `\n${renderActivityRow(`${item.status === "failed" ? "✗" : "✓"} ${item.summary}`, theme)}`;
    }
  }
  if (Array.isArray(tools?.active)) {
    for (const entry of tools.active) {
      if (!entry || typeof entry !== "object") continue;
      const item = entry as Record<string, unknown>;
      if (typeof item.summary === "string") {
        text += `\n${theme.fg("warning", "◷")} ${renderToolSummary(theme, item.summary)}`;
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
): Component {
  const details = result.details && typeof result.details === "object" ? result.details as Record<string, unknown> : {};
  const ref = typeof details.ref === "string" ? publicRef(details.ref) : undefined;
  const index = positiveSafeRuntimeIndex(ref ? Number(ref.slice(1)) : details.displayIndex);
  if (index && !context.state.runtimeIndex) {
    context.state.runtimeIndex = index;
    context.state.ref = ref ?? `#${index}`;
    queueMicrotask(() => { try { context.invalidate(); } catch {} });
  }
  if (options.isPartial) {
    return renderPartitionedStatus(`${theme.fg("accent", "● running")}${renderActivity(details, theme)}`, theme, true, context.isError);
  }

  const status = typeof details.status === "string" ? details.status : "unknown";
  const turnStatus = typeof details.turnStatus === "string" ? details.turnStatus : undefined;
  const error = typeof details.error === "string" ? details.error : undefined;
  const summary = typeof details.summary === "string" ? details.summary : error;
  const displayRef = ref ?? ("ref" in context.args ? publicRef(context.args.ref) : undefined);
  const agent = typeof details.agent === "string" ? details.agent : undefined;
  const turn = typeof details.turn === "number" && Number.isSafeInteger(details.turn) && details.turn > 0
    ? details.turn
    : undefined;

  if (status === "unknown" && error) {
    let text = theme.fg("error", "✗ subagent error");
    if (displayRef) text += theme.fg("toolTitle", ` · ${displayRef}`);
    text += `\n${theme.fg("dim", oneLine(error, 240))}`;
    return renderPartitionedStatus(text, theme, false, true);
  }

  if (context.args.action === "close" && details.closed === true) {
    let text = theme.fg("success", `✓${displayRef ? ` ${displayRef}` : ""}${agent ? ` ${agent}` : ""} · workstream closed`);
    if (error) text += `\n${theme.fg("dim", oneLine(error, 240))}`;
    return renderPartitionedStatus(text, theme, false, false);
  }

  if (context.args.action === "cancel" || context.args.action === "close") {
    const succeeded = context.args.action === "cancel" && details.cancelled === true;
    const label = succeeded ? "✓ cancel acknowledged" : `• ${context.args.action} not applied`;
    let text = theme.fg(succeeded ? "success" : context.isError ? "error" : "muted", label);
    if (displayRef) text += theme.fg("toolTitle", ` · ${displayRef}`);
    text += theme.fg("muted", ` · ${status}`);
    if (error) text += `\n${theme.fg("dim", oneLine(error, 240))}`;
    return renderPartitionedStatus(text, theme, false, context.isError);
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
    return new Text(lines.length ? lines.join("\n") : theme.fg("dim", "No subagent sessions."), 1, 0);
  }

  let text = status === "starting" || status === "running"
    ? theme.fg("warning", details.timedOut === true ? "● still running · wait expired" : "● running")
    : status === "idle" && turnStatus
      ? theme.fg(turnStatus === "failed" ? "error" : turnStatus === "interrupted" ? "warning" : "success",
          `${turnStatus === "completed" ? "✓" : turnStatus === "failed" ? "✗" : "■"} ${turnStatus}`)
      : status === "idle" ? theme.fg("success", `✓${displayRef ? ` ${displayRef}` : ""}${agent ? ` ${agent}` : ""} · session idle`)
      : status === "closed" ? theme.fg("muted", "× session closed")
      : status === "crashed" ? theme.fg("error", "✗ session crashed")
      : theme.fg("warning", "? unknown session");
  if (displayRef && !(status === "idle" && turnStatus)) text += theme.fg("toolTitle", ` · ${displayRef}`);
  if (turn) text += theme.fg("muted", ` · turn ${turn}`);
  if (typeof details.elapsedMs === "number") text += theme.fg("dim", ` · ${formatDuration(details.elapsedMs)}`);
  if (summary && !options.expanded) text += `\n${theme.fg("dim", oneLine(summary, 240))}`;
  if (options.expanded) {
    text += renderDetailSections([
      ["Summary", typeof summary === "string" ? summary : undefined],
      ["Changes", typeof details.changes === "string" ? details.changes : undefined],
      ["Evidence", typeof details.evidence === "string" ? details.evidence : undefined],
      ["Validation", typeof details.validation === "string" ? details.validation : undefined],
      ["Risks", typeof details.risks === "string" ? details.risks : undefined],
    ], theme);
    if (context.args.action === "get" && typeof details.activity === "string") {
      text += `\n${theme.fg("toolTitle", "Current")}\n${theme.fg("dim", `  ${oneLine(details.activity, 240)}`)}`;
    }
    text += renderActivity(details, theme);
  }
  if (status === "idle" && displayRef) {
    text += `\n${theme.fg("muted", `${displayRef} · workstream open · follow up gaps or close when accepted`)}`;
  }
  return renderPartitionedStatus(text, theme, false, context.isError);
}
