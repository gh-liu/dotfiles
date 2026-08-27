import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

import { stripModel } from "../protocol.ts";
import { boundedLines, collapseHome, oneLine, positiveSafeRuntimeIndex, taskTitle, type SubagentRenderArgs, type SubagentRenderContext } from "./shared.ts";

type ThemeFgColor = Parameters<Theme["fg"]>[0];
const AGENT_NAME_COLORS: readonly ThemeFgColor[] = ["syntaxKeyword", "syntaxFunction", "syntaxString", "syntaxNumber", "syntaxType", "warning", "toolDiffRemoved"];

export function agentNameColor(agent: string): ThemeFgColor {
  let hash = 0x811c9dc5;
  for (const character of agent) hash = Math.imul(hash ^ character.charCodeAt(0), 0x01000193);
  return AGENT_NAME_COLORS[(hash >>> 0) % AGENT_NAME_COLORS.length] ?? "syntaxKeyword";
}

function thinkingColor(value: string): ThemeFgColor {
  const known = new Set(["minimal", "low", "medium", "high", "xhigh", "max"]);
  return known.has(value) ? `thinking${value[0]!.toUpperCase()}${value.slice(1)}` as ThemeFgColor : "thinkingText";
}

export function renderSubagentCall(args: SubagentRenderArgs, theme: Theme, context?: SubagentRenderContext): Text {
  if (args.action === "get") return new Text(theme.fg("accent", `◷ get${args.jobId ? ` · ${oneLine(context?.state.ref ?? args.jobId, 12)}` : " · recent"}`), 0, 0);
  if (args.action === "cancel") return new Text(theme.fg("warning", `■ cancel · ${oneLine(context?.state.ref ?? args.jobId, 12)}`), 0, 0);
  const index = positiveSafeRuntimeIndex(context?.state.runtimeIndex);
  const model = args.model ?? context?.state.model;
  const thinking = args.thinking ?? context?.state.thinking;
  let text = `${index ? theme.fg("toolTitle", theme.bold(`#${index} `)) : ""}${theme.fg(agentNameColor(args.agent || "unknown"), theme.bold(args.agent || "unknown"))}`;
  if (model) text += theme.fg("accent", ` · ${stripModel(model)}`);
  if (thinking) text += theme.fg(thinkingColor(thinking), ` · ${thinking}`);
  if (args.background) text += theme.fg("muted", " · bg");
  const title = taskTitle(args.objective);
  if (title) text += theme.fg("dim", ` — ${oneLine(title, context?.expanded ? 55 : 80)}`);
  if (!context?.expanded) return new Text(text, 0, 0);
  const meta = [args.cwd ? collapseHome(args.cwd) : undefined, args.deadlineMs ? `${Math.round(args.deadlineMs / 1000)}s` : undefined].filter(Boolean);
  if (meta.length) text += theme.fg("dim", ` · ${meta.join(" · ")}`);
  for (const line of boundedLines(args.objective, 8_000, 40)) text += `\n${theme.fg("dim", `  ${line}`)}`;
  return new Text(text, 0, 0);
}
