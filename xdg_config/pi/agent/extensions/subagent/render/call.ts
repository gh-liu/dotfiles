import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

import { stripModel } from "../protocol.ts";
import { boundedLines, collapseHome, oneLine, positiveSafeRuntimeIndex, taskTitle, type SubagentRenderArgs, type SubagentRenderContext } from "./shared.ts";

type ThemeFgColor = Parameters<Theme["fg"]>[0];

/**
 * Stable per-agent accent pool. These semantic theme keys resolve to distinct
 * hues in the bundled themes (nord: blue/light-blue/green/magenta/teal/
 * yellow/red), so names are differentiated without hardcoding RGB values.
 */
const AGENT_NAME_COLORS: readonly ThemeFgColor[] = [
  "syntaxKeyword",
  "syntaxFunction",
  "syntaxString",
  "syntaxNumber",
  "syntaxType",
  "warning",
  "toolDiffRemoved",
];

/** FNV-1a 32-bit hash so the same agent name always maps to the same color. */
function hashString(value: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

/** Deterministic per-agent name color derived from the name hash. */
export function agentNameColor(agent: string): ThemeFgColor {
  const color = AGENT_NAME_COLORS[hashString(agent) % AGENT_NAME_COLORS.length];
  return color ?? "syntaxKeyword";
}

function thinkingLevelColor(thinking: string): ThemeFgColor {
  switch (thinking) {
    case "minimal":
      return "thinkingMinimal";
    case "low":
      return "thinkingLow";
    case "medium":
      return "thinkingMedium";
    case "high":
      return "thinkingHigh";
    case "xhigh":
      return "thinkingXhigh";
    case "max":
      return "thinkingMax";
    default:
      return "thinkingText";
  }
}

function formatAgentLabel(agent: string, model: string | undefined, thinking: string | undefined, theme: Theme): string {
  const separator = theme.fg("dim", " · ");
  let label = theme.fg(agentNameColor(agent), theme.bold(agent));
  if (model) label += `${separator}${theme.fg("accent", stripModel(model))}`;
  if (thinking) label += `${separator}${theme.fg(thinkingLevelColor(thinking), thinking)}`;
  return label;
}

function shortId(value: string): string {
  return value.length > 12 ? value.slice(0, 8) : value;
}

function shownId(value: string): string {
  return shortId(value);
}

export function renderSubagentCall(
  args: SubagentRenderArgs,
  theme: Theme,
  context?: SubagentRenderContext,
): Text {
  if (args.action === "list") return new Text(theme.fg("accent", "↻ refresh agents"), 0, 0);
  const expanded = context?.expanded ?? false;
  if ((args.action === "close" || args.action === "status") && !expanded) return new Text("", 0, 0);
  if (args.action === "close") return new Text(theme.fg("accent", `close · ${shownId(args.id)}`), 0, 0);
  if (args.action === "send") {
    const isSteer = args.mode === "steer";
    const icon = isSteer ? "↪" : "↷";
    const label = isSteer ? "steer" : "follow-up";
    let text = `${theme.fg("accent", `${icon} ${label}`)} ${theme.fg("muted", `· ${shownId(args.id)}`)}`;
    // Hint deadline when provided
    if (!isSteer && (args as { deadlineMs?: number }).deadlineMs) {
      text += theme.fg("dim", ` · ${Math.round(((args as { deadlineMs?: number }).deadlineMs ?? 0) / 1000)}s`);
    }
    const previewLines = boundedLines(args.message, expanded ? 8_000 : 1_200, expanded ? 40 : 6);
    for (const line of previewLines) text += `\n${theme.fg(isSteer ? "warning" : "dim", `  ${line}`)}`;
    return new Text(text, 0, 0);
  }
  if (args.action === "wait") {
    const target = args.id === undefined ? "all bg" : shownId(args.id);
    return new Text(theme.fg("accent", `◷ wait · ${target}`), 0, 0);
  }
  if (args.action === "status") {
    const target = args.id === undefined ? "all runtimes" : shownId(args.id);
    return new Text(theme.fg("accent", `● status · ${target}`), 0, 0);
  }
  if (args.action === "interrupt") {
    return new Text(theme.fg("accent", `■ interrupt · ${shownId(args.id)}`), 0, 0);
  }
  // run / start
  const runtimeIndex = positiveSafeRuntimeIndex(context?.state.runtimeIndex);
  const label = formatAgentLabel(
    args.agent || "unknown",
    args.model ?? context?.state?.model,
    args.thinking ?? context?.state?.thinking,
    theme,
  );
  const title = taskTitle(args.task);
  let text = `${runtimeIndex === undefined ? "" : theme.fg("toolTitle", theme.bold(`#${runtimeIndex} `))}${label}`;
  if (args.action === "start") text += theme.fg("muted", " · bg");
  // One-line summary so the operator can tell at a glance what this child does.
  // Expanded uses a shorter title so cwd/deadline fit on the SAME line without wrapping.
  const titleBudget = expanded ? 55 : 80;
  if (title) text += theme.fg("dim", ` — ${oneLine(title, titleBudget)}`);
  if (!expanded) return new Text(text, 0, 0);
  const meta = [
    ...(args.cwd ? [collapseHome(args.cwd)] : []),
    ...(args.deadlineMs ? [`${Math.round(args.deadlineMs / 1000)}s`] : []),
  ];
  if (meta.length > 0) text += theme.fg("dim", ` · ${meta.join(" · ")}`);
  if (args.task) {
    const lines = boundedLines(args.task, 8_000, 40);
    for (const line of lines) text += `\n${theme.fg("dim", `  ${line}`)}`;
  }
  return new Text(text, 0, 0);
}
