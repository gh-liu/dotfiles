import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

import { stripModel } from "../protocol.ts";
import { boundedLines, collapseHome, positiveSafeRuntimeIndex, publicRef, taskTitle, type SubagentRenderArgs, type SubagentRenderContext } from "./shared.ts";

type ThemeFgColor = Parameters<Theme["fg"]>[0];
const AGENT_NAME_COLORS: readonly ThemeFgColor[] = ["syntaxKeyword", "syntaxFunction", "syntaxString", "syntaxNumber", "syntaxType", "warning", "toolDiffRemoved"];

export function agentNameColor(agent: string): ThemeFgColor {
  let hash = 0x811c9dc5;
  for (const character of agent) hash = Math.imul(hash ^ character.charCodeAt(0), 0x01000193);
  return AGENT_NAME_COLORS[(hash >>> 0) % AGENT_NAME_COLORS.length] ?? "syntaxKeyword";
}

export function renderSubagentCall(args: SubagentRenderArgs, theme: Theme, context?: SubagentRenderContext): Text {
  if (args.action === "get") {
    const ref = context?.state.ref ?? publicRef(args.jobId);
    return new Text(theme.fg("accent", `◷ get · ${args.jobId ? ref ?? "resolving job…" : "recent jobs"}${args.waitMs ? ` · wait ${Math.ceil(args.waitMs / 1000)}s` : ""}`), 0, 0);
  }
  if (args.action === "cancel") {
    const ref = context?.state.ref ?? publicRef(args.jobId);
    return new Text(theme.fg("warning", `■ cancel · ${ref ?? "resolving job…"}`), 0, 0);
  }
  if (args.action === "workflow") {
    const count = args.nodes?.length ?? 0;
    let text = `${theme.fg("toolTitle", theme.bold("Workflow"))}${theme.fg("dim", ` — ${taskTitle(args.objective, 200)}`)}`;
    text += theme.fg("muted", ` · ${count} node${count === 1 ? "" : "s"}${args.background ? " · background" : ""}`);
    if (context?.expanded && args.nodes?.length) {
      for (const node of args.nodes.slice(0, 20)) {
        const dependencies = node.dependsOn?.length ? ` ← ${node.dependsOn.join(", ")}` : "";
        text += `\n${theme.fg("toolTitle", `  ${node.id}`)} ${theme.fg(agentNameColor(node.agent), node.agent)}${theme.fg("muted", dependencies)}`;
        text += `\n${theme.fg("dim", `    ${taskTitle(node.objective, 200)}`)}`;
      }
    }
    return new Text(text, 0, 0);
  }
  const index = positiveSafeRuntimeIndex(context?.state.runtimeIndex);
  const model = args.model ?? context?.state.model;
  const thinking = args.thinking ?? context?.state.thinking;
  let text = `${index ? theme.fg("toolTitle", theme.bold(`#${index} `)) : ""}${theme.fg(agentNameColor(args.agent || "unknown"), theme.bold(args.agent || "unknown"))}`;
  const title = taskTitle(args.objective, context?.expanded ? 120 : 240);
  if (title) text += theme.fg("dim", ` — ${title}`);
  if (!context?.expanded) return new Text(text, 0, 0);
  const meta = [model ? stripModel(model) : undefined, thinking, args.cwd ? collapseHome(args.cwd) : undefined].filter(Boolean);
  if (meta.length) text += theme.fg("dim", ` · ${meta.join(" · ")}`);
  const sections: Array<[string, string | string[] | undefined]> = [
    ["Outcome", args.objective], ["Scope", args.scope], ["Context", args.context],
    ["Constraints", args.constraints], ["Acceptance", args.acceptance],
  ];
  for (const [label, value] of sections) {
    if (!value || (Array.isArray(value) && value.length === 0)) continue;
    text += `\n${theme.fg("toolTitle", `  ${label}`)}`;
    const body = Array.isArray(value) ? value.map((item) => `• ${item}`).join("\n") : value;
    for (const line of boundedLines(body, 8_000, 40)) text += `\n${theme.fg("dim", `    ${line}`)}`;
  }
  return new Text(text, 0, 0);
}
