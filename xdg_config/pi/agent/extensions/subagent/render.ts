import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

type SubagentRenderArgs =
  | { action: "list" }
  | { action: "run" | "start"; agent: string; task: string; cwd?: string; deadlineMs?: number }
  | { action: "status" | "wait" | "interrupt"; operationId: string; timeoutMs?: number }
  | { action: "close" };

interface SubagentRenderState {
  spinnerFrame?: number;
  spinnerTimer?: ReturnType<typeof setInterval>;
}

interface SubagentRenderResult {
  content: Array<{ type: string; text?: string }>;
  details?: unknown;
}

interface SubagentRenderContext {
  args: SubagentRenderArgs;
  isError: boolean;
  state: SubagentRenderState;
  invalidate(): void;
}

const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

function oneLine(text: string, maxCharacters = 120): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  return normalized.length <= maxCharacters
    ? normalized
    : `${normalized.slice(0, maxCharacters - 1)}…`;
}

function resultText(result: SubagentRenderResult): string {
  return result.content.find((part) => part.type === "text")?.text ?? "";
}

export function renderSubagentCall(args: SubagentRenderArgs, theme: Theme): Text {
  if (args.action === "list") return new Text(theme.fg("accent", "refresh agents"), 0, 0);
  if (args.action === "close") return new Text(theme.fg("accent", "close runtime"), 0, 0);
  if (args.action !== "run" && args.action !== "start") {
    return new Text(theme.fg("accent", `${args.action} — ${"operationId" in args ? args.operationId : ""}`), 0, 0);
  }
  let text = theme.fg("accent", theme.bold(args.agent || "unknown"));
  if (args.task) text += theme.fg("dim", ` — ${oneLine(args.task)}`);
  if (args.cwd) text += theme.fg("muted", ` (${args.cwd})`);
  return new Text(text, 0, 0);
}

export function renderSubagentResult(
  result: SubagentRenderResult,
  { expanded, isPartial }: { expanded: boolean; isPartial: boolean },
  theme: Theme,
  context: SubagentRenderContext,
): Text {
  const details = result.details as { status?: string; summary?: string } | undefined;
  const output = details?.summary ?? resultText(result);
  const preview = oneLine(output, 160);
  const state = context.state;
  let text: string;
  if (isPartial) {
    state.spinnerFrame ??= 0;
    if (!state.spinnerTimer) {
      state.spinnerTimer = setInterval(() => {
        state.spinnerFrame = ((state.spinnerFrame ?? 0) + 1) % SPINNER_FRAMES.length;
        context.invalidate();
      }, 80);
      state.spinnerTimer.unref?.();
    }
    text = theme.fg("warning", SPINNER_FRAMES[state.spinnerFrame]);
  } else if (context.isError || details?.status === "failed") {
    if (state.spinnerTimer) clearInterval(state.spinnerTimer);
    state.spinnerTimer = undefined;
    text = theme.fg("error", "✗ Failed");
  } else {
    if (state.spinnerTimer) clearInterval(state.spinnerTimer);
    state.spinnerTimer = undefined;
    text = theme.fg("success", "✓ Completed");
  }

  if (context.args.action === "list" && output) {
    for (const line of output.split("\n")) text += `\n${theme.fg("dim", line)}`;
  } else if (expanded && output) {
    const lines = output.split("\n");
    for (const line of lines.slice(0, 20)) text += `\n${theme.fg("dim", line)}`;
    if (lines.length > 20) text += `\n${theme.fg("muted", "… output truncated in UI")}`;
  } else if (preview) {
    text += theme.fg("dim", ` — ${preview}`);
  }
  return new Text(text, 0, 0);
}
