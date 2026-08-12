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
  expanded?: boolean;
  state: SubagentRenderState;
  invalidate(): void;
}

const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

function oneLine(text: string, maxCharacters = 160): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  return normalized.length <= maxCharacters
    ? normalized
    : `${normalized.slice(0, maxCharacters - 1)}…`;
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

function resultText(result: SubagentRenderResult): string {
  return result.content.find((part) => part.type === "text")?.text ?? "";
}

export function renderSubagentCall(
  args: SubagentRenderArgs,
  theme: Theme,
  context?: SubagentRenderContext,
): Text {
  if (args.action === "list") return new Text(theme.fg("accent", "refresh agents"), 0, 0);
  if (args.action === "close") return new Text(theme.fg("accent", "close runtime"), 0, 0);
  if (args.action !== "run" && args.action !== "start") {
    return new Text(theme.fg("accent", `${args.action} — ${"operationId" in args ? args.operationId : ""}`), 0, 0);
  }
  let text = theme.fg("accent", theme.bold(args.agent || "unknown"));
  if (args.action === "start") text += theme.fg("muted", " · background");
  if (args.cwd) text += theme.fg("muted", ` · ${args.cwd}`);
  if (args.task) {
    const expanded = context?.expanded ?? false;
    const lines = boundedLines(args.task, expanded ? 4_000 : 480, expanded ? 20 : 3);
    for (const line of lines) text += `\n${theme.fg("dim", `  ${line}`)}`;
  }
  return new Text(text, 0, 0);
}

function stopSpinner(state: SubagentRenderState): void {
  if (state.spinnerTimer) clearInterval(state.spinnerTimer);
  state.spinnerTimer = undefined;
}

function statusFrom(details: Record<string, unknown>): string | undefined {
  if (typeof details.status === "string") return details.status;
  const snapshot = details.snapshot;
  if (snapshot && typeof snapshot === "object" && typeof (snapshot as { status?: unknown }).status === "string") {
    return (snapshot as { status: string }).status;
  }
  return undefined;
}

function errorFrom(details: Record<string, unknown>): string | undefined {
  if (typeof details.error === "string") return details.error;
  const snapshot = details.snapshot;
  if (snapshot && typeof snapshot === "object" && typeof (snapshot as { error?: unknown }).error === "string") {
    return (snapshot as { error: string }).error;
  }
  return undefined;
}

export function renderSubagentResult(
  result: SubagentRenderResult,
  { expanded, isPartial }: { expanded: boolean; isPartial: boolean },
  theme: Theme,
  context: SubagentRenderContext,
): Text {
  const details = result.details && typeof result.details === "object"
    ? result.details as Record<string, unknown>
    : {};
  const detailOutput = typeof details.summary === "string" ? details.summary : errorFrom(details);
  const output = detailOutput ?? resultText(result);
  const preview = oneLine(output, 160);
  const state = context.state;
  const status = statusFrom(details);
  const action = context.args.action;
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
  } else if (status === "interrupted" || details.controllerCancellation === true) {
    stopSpinner(state);
    text = theme.fg("warning", "■ Interrupted");
  } else if (context.isError) {
    stopSpinner(state);
    text = theme.fg("error", "✗ Failed");
  } else if (action === "list") {
    stopSpinner(state);
    text = theme.fg("accent", "Registered agents");
  } else if (action === "close" && status === "closed") {
    stopSpinner(state);
    text = theme.fg("success", "✓ Closed");
  } else if (action === "start" && status === "running") {
    stopSpinner(state);
    text = theme.fg("accent", "↗ Started");
  } else if (action === "wait" && details.reason === "timeout") {
    stopSpinner(state);
    text = theme.fg("warning", "◷ Still running");
  } else if (action === "interrupt") {
    stopSpinner(state);
    text = details.accepted === true
      ? theme.fg("warning", "■ Interrupt requested")
      : theme.fg("muted", `• Already ${status ?? "settled"}`);
  } else if (status === "running") {
    stopSpinner(state);
    text = theme.fg("warning", "● Running");
  } else if (status === "failed") {
    stopSpinner(state);
    text = theme.fg("error", "✗ Failed");
  } else {
    stopSpinner(state);
    text = theme.fg("success", "✓ Completed");
  }

  const showOutput =
    ((action === "run" || action === "wait") && details.reason !== "timeout")
    || context.isError
    || status === "failed";
  if (action === "list" && output) {
    for (const line of output.split("\n")) text += `\n${theme.fg("dim", line)}`;
  } else if (showOutput && expanded && output) {
    const lines = output.split("\n");
    for (const line of lines.slice(0, 20)) text += `\n${theme.fg("dim", line)}`;
    if (lines.length > 20) text += `\n${theme.fg("muted", "… output truncated in UI")}`;
  } else if (showOutput && preview) {
    text += theme.fg("dim", ` — ${preview}`);
  }
  return new Text(text, 0, 0);
}
