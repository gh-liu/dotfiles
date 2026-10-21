import { keyHint, truncateToVisualLines, type ToolDefinition, type Theme } from "@earendil-works/pi-coding-agent";
import { Container, Spacer, Text, type Component } from "@earendil-works/pi-tui";
import type { Details, Request } from "./runner.ts";

// The public truncator handles wrapped lines; clipping is recalculated at the actual render width.
function preview(text: string, limit: number, hint: (hidden: number) => string): Component {
  return {
    render(width) {
      const { visualLines, skippedCount } = truncateToVisualLines(text, limit, width, 0, "start");
      return skippedCount ? [...visualLines, ...new Text(hint(skippedCount), 0, 0).render(width)] : visualLines;
    },
    invalidate() {},
  };
}

// Escape terminal controls from model/tool supplied text, retaining newlines and normal Unicode.
function display(text: string): string {
  return text.replace(/\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)/g, "")
    .replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "")
    .replace(/[\x00-\x08\x0b-\x1f\x7f-\x9f]/g, "").replace(/\t/g, "   ");
}
function duration(ms: number): string { return ms < 1000 ? `${Math.round(ms)}ms` : `${(ms / 1000).toFixed(1)}s`; }

export const renderCall = (args: Request, theme: Theme, ctx: Parameters<NonNullable<ToolDefinition["renderCall"]>>[2]) => {
  const component = new Container();
  component.addChild(new Text(theme.fg("toolTitle", theme.bold("subagent")), 0, 0));
  const request = display([args.description, args.task].filter(Boolean).join("\n\n"));
  const hint = (hidden: number) => theme.fg("muted", `… (${hidden} more lines, ${keyHint("app.tools.expand", "to expand")})`);
  component.addChild(ctx.expanded ? new Text(request, 0, 0) : preview(request, 10, hint));
  return component;
};

export const renderResult: NonNullable<ToolDefinition<any, Details>["renderResult"]> = (result, options, theme, ctx) => {
  const component = new Container();
  const details = result.details;
  const add = (text: string) => component.addChild(new Text(text, 0, 0));
  const calls = details?.calls ?? [];
  const running = calls.filter((call) => call.status === "running");
  const completedSlots = Math.max(0, 8 - running.length);
  const shown = options.expanded ? calls : [
    ...running.slice(0, 8),
    ...(completedSlots ? calls.filter((call) => call.status !== "running").slice(-completedSlots) : []),
  ];
  if (calls.length || (options.isPartial && details)) component.addChild(new Spacer(1));
  const hidden = (details?.omitted ?? 0) + calls.length - shown.length;
  if (hidden) add(theme.fg("muted", `… (${hidden} hidden activities${details?.omitted ? "; full records in child session" : `, ${keyHint("app.tools.expand", "to expand")}`})`));
  const hiddenRunning = (details?.running ?? 0) - shown.filter((call) => call.status === "running").length;
  if (hiddenRunning > 0) add(theme.fg("muted", `… (${hiddenRunning} more tools running)`));
  for (const call of shown) {
    const icon = { running: "…", ok: "✓", error: "✗", cancelled: "⊘" }[call.status];
    const color = call.status === "error" ? "error" : call.status === "ok" ? "success" : "muted";
    const args = options.expanded || call.args.length <= 80 ? call.args : `${call.args.slice(0, 77)}…`;
    add(`${theme.fg(color, icon)} ${theme.fg("toolTitle", display(call.name))} ${theme.fg("muted", display(args))}${call.durationMs === undefined ? "" : theme.fg("dim", ` ${duration(call.durationMs)}`)}`);
  }
  if (options.isPartial && details) add(theme.fg("muted", `… ${details.activity}`));
  const output = display(result.content.filter((part) => part.type === "text").map((part) => part.text).join("\n"));
  if (!options.isPartial && output) {
    component.addChild(new Spacer(1));
    const styled = theme.fg(ctx.isError ? "error" : "toolOutput", output);
    component.addChild(options.expanded ? new Text(styled, 0, 0) : preview(styled, 5,
      (hidden) => theme.fg("muted", `… (${hidden} more lines, ${keyHint("app.tools.expand", "to expand")})`)));
  }
  if (details) {
    component.addChild(new Spacer(1));
    const elapsed = options.isPartial ? Date.now() - details.startedAt : ctx.durationMs ?? details.durationMs ?? 0;
    const thinking = details.effectiveThinking
      ? `Thinking ${details.requestedThinking !== details.effectiveThinking ? `${details.requestedThinking} → ` : ""}${details.effectiveThinking} · ` : "";
    add(theme.fg("muted", `${thinking}${options.isPartial ? "Elapsed" : "Took"} ${duration(elapsed)}`));
    if (details.sessionFile && (options.expanded || details.omitted)) add(theme.fg("dim", `Child session: ${display(details.sessionFile)}`));
  }
  return component;
};
