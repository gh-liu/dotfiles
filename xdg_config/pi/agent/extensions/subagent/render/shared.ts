import type { Theme } from "@earendil-works/pi-coding-agent";
import { redactSecrets } from "../output.ts";
import { Box, Container, Text } from "@earendil-works/pi-tui";

type SubagentRenderArgs =
  | {
      action: "run"; agent: string; task: string; background?: boolean;
      model?: string; thinking?: string;
    }
  | { action: "followup"; ref: string; task: string; background?: boolean; agent?: string; model?: string; thinking?: string }
  | { action: "get"; ref?: string; waitMs?: number }
  | { action: "cancel"; ref: string }
  | { action: "close"; ref: string };

interface SubagentRenderState {
  spinnerFrame?: number;
  spinnerTimer?: ReturnType<typeof setInterval>;
  /** Immutable per-row runtime identity, learned only from authoritative result details. */
  runtimeIndex?: number;
  /** Session-local public alias learned from authoritative result details. */
  ref?: string;
  /** Effective model learned from authoritative progress/update details. */
  model?: string;
  /** Effective thinking level learned from authoritative progress/update details. */
  thinking?: string;
  /** Monotonic turn number learned from authoritative progress/update details. */
  turn?: number;
  /** Prevents the result-triggered repaint from recursively scheduling itself. */
  runtimeIndexInvalidateQueued?: boolean;
}

interface SubagentRenderResult {
  content: Array<{ type: string; text?: string }>;
  details?: unknown;
}

interface SubagentRenderContext {
  args: SubagentRenderArgs;
  isError: boolean;
  isPartial?: boolean;
  expanded?: boolean;
  state: SubagentRenderState;
  invalidate(): void;
}

function statusBackground(theme: Theme, isPartial: boolean, isError: boolean): (text: string) => string {
  const color = isPartial ? "toolPendingBg" : isError ? "toolErrorBg" : "toolSuccessBg";
  return (text) => theme.bg(color, text);
}

function renderThinkingLevel(theme: Theme, level: string): string {
  return theme.getThinkingBorderColor(level as Parameters<Theme["getThinkingBorderColor"]>[0])(level);
}

/** Keep the first status line highlighted while rendering verbose output on the terminal background. */
function renderPartitionedStatus(text: string, theme: Theme, isPartial: boolean, isError: boolean): Container {
  const newline = text.indexOf("\n");
  const status = newline < 0 ? text : text.slice(0, newline);
  const body = newline < 0 ? "" : text.slice(newline + 1);
  const component = new Container();
  const statusBox = new Box(1, 0, statusBackground(theme, isPartial, isError));
  statusBox.addChild(new Text(status, 0, 0));
  component.addChild(statusBox);
  if (body) component.addChild(new Text(body, 1, 0));
  return component;
}

function oneLine(text: string, maxCharacters = 160): string {
  const normalized = redactSecrets(text).replace(/\s+/g, " ").trim();
  return normalized.length <= maxCharacters
    ? normalized
    : `${normalized.slice(0, maxCharacters - 1)}…`;
}

/** Highlight only the leading tool name; keep arguments and paths low contrast. */
function renderToolSummary(theme: Theme, summary: string, maxCharacters = 200): string {
  const bounded = oneLine(summary, maxCharacters);
  const match = /^(\S+)(.*)$/.exec(bounded);
  if (!match) return theme.fg("muted", bounded);
  return `${theme.fg("syntaxFunction", match[1])}${theme.fg("muted", match[2])}`;
}

function formatDuration(ms: number): string {
  // Seconds-only keeps the live view compact and stable between heartbeat updates.
  return `${Math.max(0, Math.ceil(ms / 1000))}s`;
}

function boundedLines(text: string, maxCharacters: number, maxLines: number): string[] {
  const lines = text.replace(/\r\n?/g, "\n").trim().split("\n");
  const selected = lines.slice(0, maxLines);
  let bounded = selected.join("\n");
  const truncated = lines.length > maxLines || bounded.length > maxCharacters;
  if (bounded.length > maxCharacters) bounded = bounded.slice(0, maxCharacters).replace(/\s+$/g, "");
  const result = bounded.split("\n");
  if (truncated) result[result.length - 1] = `${result[result.length - 1]}…`;
  return result;
}

/** One-line human summary of the work order: strip labels/markdown, first meaningful text. */
function taskTitle(task: string | undefined, maxCharacters = 80): string {
  if (!task) return "";
  const firstLine = task
    .split("\n")
    .map((line) => line.trim())
    .find((line) => line.length > 0 && !line.startsWith("#")) ?? "";
  return oneLine(firstLine.replace(/^outcome\s*[:：]\s*/i, ""), maxCharacters);
}

/** Shared expanded sections: label + bounded dim lines, skipping empty values. */
function renderDetailSections(sections: Array<[string, string | undefined]>, theme: Theme): string {
  let text = "";
  for (const [label, value] of sections) {
    if (!value?.trim()) continue;
    text += `\n${theme.fg("toolTitle", label)}`;
    for (const line of boundedLines(value, 4_000, 20)) if (line) text += `\n${theme.fg("dim", `  ${line}`)}`;
  }
  return text;
}

/** Shared single activity row: Thinking accent, ✓/✗ tool summary, else dim. Single-line normalized. */
function renderActivityRow(line: string, theme: Theme): string {
  const bounded = oneLine(line, 200);
  if (bounded === "✓ Thinking") return theme.fg("accent", bounded);
  const match = /^([✓✗])\s+(.+)$/.exec(bounded);
  if (!match) return theme.fg("dim", `  ${bounded}`);
  return `  ${theme.fg(match[1] === "✗" ? "error" : "success", match[1])} ${renderToolSummary(theme, match[2])}`;
}

function positiveSafeRuntimeIndex(value: unknown): number | undefined {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0 ? value : undefined;
}

function publicRef(value: string | undefined): string | undefined {
  if (!value) return undefined;
  const match = /^(?:#)?([1-9]\d*)$/.exec(value);
  return match ? `#${match[1]}` : undefined;
}

export { boundedLines, formatDuration, oneLine, positiveSafeRuntimeIndex, publicRef, renderActivityRow, renderDetailSections, renderPartitionedStatus, renderThinkingLevel, renderToolSummary, statusBackground, taskTitle };
export type { SubagentRenderArgs, SubagentRenderContext, SubagentRenderResult, SubagentRenderState };
