import { type Theme } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

import { boundedLines, positiveSafeRuntimeIndex, publicRef, statusBackground, taskTitle, type SubagentRenderArgs, type SubagentRenderContext } from "./shared.ts";

type ThemeFgColor = Parameters<Theme["fg"]>[0];
const AGENT_NAME_COLORS: readonly ThemeFgColor[] = ["syntaxKeyword", "syntaxFunction", "syntaxString", "syntaxNumber", "syntaxType", "warning", "toolDiffRemoved"];

export function agentNameColor(agent: string): ThemeFgColor {
  let hash = 0x811c9dc5;
  for (const character of agent) hash = Math.imul(hash ^ character.charCodeAt(0), 0x01000193);
  return AGENT_NAME_COLORS[(hash >>> 0) % AGENT_NAME_COLORS.length] ?? "syntaxKeyword";
}

export function renderSubagentCall(args: SubagentRenderArgs, theme: Theme, context?: SubagentRenderContext): Text | Box {
  if (args.action === "get") {
    const ref = context?.state.ref ?? publicRef(args.ref);
    return renderCallBlock(theme.fg("accent", `◷ get · ${args.ref ? ref ?? "resolving session…" : "sessions"}${args.waitMs ? ` · wait ${Math.ceil(args.waitMs / 1000)}s` : ""}`), theme, context);
  }
  if (args.action === "cancel" || args.action === "close") {
    const ref = context?.state.ref ?? publicRef(args.ref);
    const color = args.action === "cancel" ? "warning" : "muted";
    return renderCallBlock(theme.fg(color, `${args.action === "cancel" ? "■" : "×"} ${args.action} · ${ref ?? "resolving session…"}`), theme, context);
  }
  const index = positiveSafeRuntimeIndex(context?.state.runtimeIndex);
  const model = args.model ?? context?.state.model;
  const thinking = args.thinking ?? context?.state.thinking;
  const ref = args.action === "followup" ? publicRef(args.ref) : index ? `#${index}` : undefined;
  const agent = args.action === "run" ? args.agent : args.agent ?? "subagent";
  const continuation = args.action === "followup" ? theme.fg("accent", "↳ ") : "";
  let text = `${continuation}${ref ? theme.fg("toolTitle", theme.bold(`${ref} `)) : ""}${theme.fg(agentNameColor(agent), theme.bold(agent))}`;
  if (model) text += theme.fg("muted", ` · ${model}`);
  if (thinking) text += theme.fg("muted", ` · ${thinking}`);
  if (args.action === "followup" && context?.state.turn) text += theme.fg("muted", ` · turn ${context.state.turn}`);
  const title = taskTitle(args.task, context?.expanded ? 120 : 240);
  if (title) text += theme.fg("dim", ` — ${title}`);
  if (!context?.expanded) return renderCallBlock(text, theme, context);
  const meta = [args.background ? "background" : undefined].filter(Boolean);
  if (meta.length) text += theme.fg("dim", ` · ${meta.join(" · ")}`);
  text += `\n${theme.fg("toolTitle", "  Task")}`;
  for (const line of boundedLines(args.task, 8_000, 40)) text += `\n${theme.fg("dim", `    ${line}`)}`;
  return renderCallBlock(text, theme, context);
}

function renderCallBlock(text: string, theme: Theme, context?: SubagentRenderContext): Box {
  const box = new Box(1, 0, statusBackground(theme, context?.isPartial ?? true, context?.isError ?? false));
  box.addChild(new Text(text, 0, 0));
  return box;
}
