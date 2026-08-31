import { type Theme } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

import { agentNameColor } from "./call.ts";
import { boundedLines, formatCountdown, oneLine, taskTitle } from "./shared.ts";

export const SUBAGENT_COMPLETION_MESSAGE = "subagent-operation-settled";

export interface SubagentCompletionDetails {
  jobId: string;
  ref: string;
  agent: string;
  model?: string;
  thinking?: string;
  task: string;
  status: "completed" | "failed" | "interrupted";
  summary: string;
  runtimeStatus: "running" | "idle" | "crashed";
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
  const summaryOneLine = oneLine(summaryRaw, 240);
  const completionTitle = taskTitle(details.task, expanded ? 160 : 80);
  let text = `${theme.fg(color, marker)} ${theme.fg("toolTitle", `${details.ref} `)}${theme.fg(color, status)}`;
  // Short agent name only: the full label (model/thinking) already sits on the tool-call title.
  const agentLabel = details.agent;
  if (details.agent) text += `${theme.fg("muted", " · ")}${theme.fg(agentNameColor(details.agent), agentLabel)}`;
  if (!expanded && typeof details.elapsedMs === "number") text += theme.fg("muted", ` · ${formatCountdown(details.elapsedMs)}`);
  if (!expanded && completionTitle) text += theme.fg("muted", ` · ${completionTitle}`);
  if (!expanded && summaryOneLine) text += `\n${theme.fg("dim", summaryOneLine)}`;
  if (expanded) {
    if (completionTitle) text += `\n${theme.fg("muted", `  task: ${completionTitle}`)}`;
    const lines = boundedLines(summaryRaw, 4_000, 20);
    for (const line of lines) if (line) text += `\n${theme.fg("dim", `  ${line}`)}`;
    if (typeof details.elapsedMs === "number") {
      text += `\n${theme.fg("muted", `  elapsed ${formatCountdown(details.elapsedMs)}`)}`;
    }
  }
  return text;
}

const completionBg = (entries: readonly SubagentCompletionDetails[]): "toolSuccessBg" | "toolErrorBg" | "toolPendingBg" => {
  const statuses = new Set(entries.map((entry) => entry.status));
  if (statuses.size !== 1) return "toolPendingBg";
  const status = entries[0]?.status;
  return status === "completed" ? "toolSuccessBg" : status === "failed" ? "toolErrorBg" : "toolPendingBg";
};

export function renderSubagentCompletion(
  message: { content: unknown; details?: SubagentCompletionPayload },
  { expanded, outputPad }: { expanded: boolean; outputPad: number },
  theme: Theme,
): Box {
  const raw = message.details;
  const entries: SubagentCompletionDetails[] = !raw
    ? [{ ...({} as SubagentCompletionDetails) }]
    : "batch" in raw ? raw.batch : [raw];
  const box = new Box(outputPad, 0, (value) => theme.bg(completionBg(entries), value));
  entries.forEach((entry, index) => {
    if (index > 0) box.addChild(new Text(theme.fg("muted", "─"), 0, 0));
    box.addChild(new Text(completionEntryText(entry, { expanded }, theme), 0, 0));
  });
  return box;
}
