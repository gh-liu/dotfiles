import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

import { formatCountdown, oneLine, positiveSafeRuntimeIndex, type SubagentRenderContext, type SubagentRenderResult } from "./shared.ts";

const FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

export function renderSubagentResult(result: SubagentRenderResult, options: { expanded: boolean; isPartial: boolean }, theme: Theme, context: SubagentRenderContext): Text {
  const details = result.details && typeof result.details === "object" ? result.details as Record<string, unknown> : {};
  const ref = typeof details.ref === "string" && /^#[1-9]\d*$/.test(details.ref) ? details.ref : undefined;
  const index = positiveSafeRuntimeIndex(ref ? Number(ref.slice(1)) : details.displayIndex);
  if (index && !context.state.runtimeIndex) {
    context.state.runtimeIndex = index;
    context.state.ref = ref ?? `#${index}`;
    queueMicrotask(() => { try { context.invalidate(); } catch {} });
  }
  if (options.isPartial) {
    context.state.spinnerFrame ??= 0;
    if (!context.state.spinnerTimer) {
      context.state.spinnerTimer = setInterval(() => { context.state.spinnerFrame = ((context.state.spinnerFrame ?? 0) + 1) % FRAMES.length; context.invalidate(); }, 80);
      context.state.spinnerTimer.unref?.();
    }
    const deadline = context.args.action === "run" ? context.args.deadlineMs : undefined;
    const countdown = deadline ? ` ${formatCountdown(deadline - (Date.now() - (typeof details.startedAt === "number" ? details.startedAt : (context.state.startedAt ??= Date.now()))))}` : "";
    const progress = result.content.find((part) => part.type === "text")?.text;
    return new Text(theme.fg("warning", FRAMES[context.state.spinnerFrame]) + countdown + (progress ? theme.fg("dim", ` — ${oneLine(progress, 240)}`) : ""), 0, 0);
  }
  if (context.state.spinnerTimer) clearInterval(context.state.spinnerTimer);
  context.state.spinnerTimer = undefined;
  const status = typeof details.status === "string" ? details.status : undefined;
  const error = typeof details.error === "string" ? details.error : undefined;
  const summary = typeof details.summary === "string" ? details.summary : error;
  let text = context.isError || status === "failed" ? theme.fg("error", "✗ failed")
    : status === "running" ? theme.fg("warning", "● running")
    : status === "interrupted" ? theme.fg("warning", "■ interrupted")
    : context.args.action === "cancel" ? theme.fg("warning", details.cancelled === true ? "■ cancelled" : "• already terminal")
    : theme.fg("success", "✓ completed");
  if (typeof details.elapsedMs === "number") text += theme.fg("dim", ` · ${formatCountdown(details.elapsedMs)}`);
  if (summary) text += options.expanded ? `\n${summary.split("\n").slice(0, 20).map((line) => theme.fg("dim", line)).join("\n")}` : `\n${theme.fg("dim", oneLine(summary, 240))}`;
  return new Text(text, 0, 0);
}
