import { type Theme } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

import { agentNameColor } from "./call.ts";
import { boundedLines, formatDuration, oneLine } from "./shared.ts";

export const SUBAGENT_COMPLETION_MESSAGE = "subagent-operation-settled";

export interface SubagentCompletionDetails {
  jobId: string;
  /** Internal operation/delivery identity; never rendered or exposed to the model. */
  operationId: string;
  ref: string;
  agent: string;
  model?: string;
  thinking?: string;
  task: string;
  status: "completed" | "failed" | "interrupted";
  /** True only when the session is idle and can accept a followup. */
  sessionOpen?: true;
  summary: string;
  changes?: string;
  evidence?: string;
  validation?: string;
  risks?: string;
  /** Last bounded, redacted activity rows retained for failed/interrupted diagnostics. */
  recentActivity?: string[];
  /** Wall-clock duration of the settled operation in milliseconds, when known. */
  elapsedMs?: number;
}

/** Several background operations settled together and are reported as one card. */
export interface SubagentCompletionBatch {
  batch: SubagentCompletionDetails[];
}

export type SubagentCompletionPayload = SubagentCompletionDetails | SubagentCompletionBatch;

// --- Completion notification (custom message) ---
function completionEntryText(
  details: SubagentCompletionDetails,
  { expanded }: { expanded: boolean },
  theme: Theme,
): string {
  const status = details.status ?? "failed";
  const color = status === "completed" ? "success" : status === "interrupted" ? "warning" : "error";
  const marker = status === "completed" ? "✓" : status === "interrupted" ? "■" : "✗";
  const summaryRaw = details.summary ?? "";
  let text = `${theme.fg(color, marker)} ${theme.fg(agentNameColor(details.agent), theme.bold(details.agent))}`;
  if (status !== "completed") text += theme.fg(color, ` · ${status}`);
  if (typeof details.elapsedMs === "number") text += theme.fg("muted", ` · ${formatDuration(details.elapsedMs)}`);
  if (!expanded && summaryRaw) {
    for (const line of boundedLines(summaryRaw, 480, 2)) text += `\n${theme.fg("dim", `  ${line}`)}`;
  }
  const hasDetails = [details.task, summaryRaw, details.changes, details.evidence, details.validation, details.risks, ...(details.recentActivity ?? [])]
    .some((value) => typeof value === "string" && value.trim());
  if (!expanded) {
    const affordance = details.sessionOpen ? "session open · follow-up or close" : "session unavailable";
    text += `\n${theme.fg("muted", `  ${details.ref} · ${affordance}${hasDetails ? " · expand for details" : ""}`)}`;
  }
  if (expanded) {
    const sections: Array<[string, string | undefined]> = [
      ["Task", details.task], ["Summary", summaryRaw], ["Changes", details.changes], ["Evidence", details.evidence],
      ["Validation", details.validation], ["Risks", details.risks],
    ];
    for (const [label, value] of sections) {
      if (!value?.trim()) continue;
      text += `\n${theme.fg("toolTitle", label)}`;
      for (const line of boundedLines(value, 4_000, 20)) if (line) text += `\n${theme.fg("dim", `  ${line}`)}`;
    }
    if (details.recentActivity?.length) {
      text += `\n${theme.fg("toolTitle", "Recent activity")}`;
      for (const line of details.recentActivity.slice(-8)) text += `\n${theme.fg("dim", `  ${oneLine(line, 200)}`)}`;
    }
    text += `\n${theme.fg("muted", `${details.ref} · ${details.sessionOpen ? "session open · follow-up or close" : "session unavailable"}`)}`;
  }
  return text;
}

export function renderSubagentCompletion(
  message: { content: unknown; details?: SubagentCompletionPayload },
  { expanded, outputPad }: { expanded: boolean; outputPad: number },
  theme: Theme,
): Box {
  const raw = message.details;
  const entries: SubagentCompletionDetails[] = !raw
    ? [{ ...({} as SubagentCompletionDetails) }]
    : "batch" in raw ? raw.batch : [raw];
  const box = new Box(outputPad, 0);
  entries.forEach((entry, index) => {
    if (index > 0) box.addChild(new Text(theme.fg("muted", "─"), 0, 0));
    box.addChild(new Text(completionEntryText(entry, { expanded }, theme), 0, 0));
  });
  return box;
}
