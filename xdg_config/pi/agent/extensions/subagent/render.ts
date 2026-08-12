import { type Theme } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

export const SUBAGENT_COMPLETION_MESSAGE = "subagent-operation-settled";

export interface SubagentCompletionDetails {
  runId: string;
  operationId: string;
  agent: string;
  task: string;
  status: "completed" | "failed" | "interrupted";
  summary: string;
  runtimeStatus: "running" | "idle" | "crashed";
}

type SubagentRenderArgs =
  | { action: "list" }
  | { action: "run" | "start"; agent: string; task: string; cwd?: string; deadlineMs?: number }
  | { action: "status"; id: string }
  | { action: "send"; id: string; mode: "follow_up"; message: string; deadlineMs?: number }
  | { action: "send"; id: string; mode: "steer"; message: string; expectedOperationId: string }
  | { action: "wait"; id: string; operationId: string; timeoutMs?: number }
  | { action: "interrupt"; id: string; expectedOperationId: string }
  | { action: "close"; id: string };

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

export function renderSubagentCompletion(
  message: { content: unknown; details?: SubagentCompletionDetails },
  { expanded, outputPad }: { expanded: boolean; outputPad: number },
  theme: Theme,
): Box {
  const details = message.details;
  const status = details?.status ?? "failed";
  const color = status === "completed" ? "success" : status === "interrupted" ? "warning" : "error";
  const marker = status === "completed" ? "✓" : status === "interrupted" ? "■" : "✗";
  const agent = oneLine(details?.agent ?? "subagent", 80);
  const summary = oneLine(details?.summary ?? (typeof message.content === "string" ? message.content : ""));
  let text = `${theme.fg(color, marker)} ${theme.bold(agent)} ${status}`;
  if (!expanded && details?.task) text += theme.fg("muted", ` · ${oneLine(details.task, 80)}`);
  if (!expanded && summary) text += theme.fg("dim", ` — ${oneLine(summary, 120)}`);
  if (expanded) {
    if (details?.task) {
      text += `\n${theme.fg("muted", `  task: ${oneLine(details.task, 240)}`)}`;
    }
    const expandedSummary = details?.summary ?? (typeof message.content === "string" ? message.content : "");
    for (const line of boundedLines(expandedSummary, 4_000, 20)) {
      if (line) text += `\n${theme.fg("dim", `  ${line}`)}`;
    }
    if (details) {
      text += `\n${theme.fg("muted", `  run ${details.runId} · operation ${details.operationId} · runtime ${details.runtimeStatus}`)}`;
    }
  }
  const box = new Box(outputPad, 0, (value) => theme.bg("customMessageBg", value));
  box.addChild(new Text(text, 0, 0));
  return box;
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

function shortId(value: string): string {
  return value.length > 12 ? value.slice(0, 8) : value;
}

function shownId(value: string, expanded: boolean): string {
  return expanded ? value : shortId(value);
}

export function renderSubagentCall(
  args: SubagentRenderArgs,
  theme: Theme,
  context?: SubagentRenderContext,
): Text {
  if (args.action === "list") return new Text(theme.fg("accent", "refresh agents"), 0, 0);
  const expanded = context?.expanded ?? false;
  if (args.action === "close") return new Text(theme.fg("accent", `close · ${shownId(args.id, expanded)}`), 0, 0);
  if (args.action === "send") {
    let text = theme.fg("accent", `${args.mode === "steer" ? "steer" : "follow up"} · ${shownId(args.id, expanded)}`);
    for (const line of boundedLines(args.message, expanded ? 8_000 : 1_200, expanded ? 40 : 6)) {
      text += `\n${theme.fg("dim", `  ${line}`)}`;
    }
    return new Text(text, 0, 0);
  }
  if (args.action !== "run" && args.action !== "start") {
    const operation = args.action === "wait" ? ` · operation ${shownId(args.operationId, expanded)}` : "";
    return new Text(theme.fg("accent", `${args.action} · ${shownId(args.id, expanded)}${operation}`), 0, 0);
  }
  let text = theme.fg("accent", theme.bold(args.agent || "unknown"));
  if (args.action === "start") text += theme.fg("muted", " · background");
  if (args.cwd) text += theme.fg("muted", ` · ${args.cwd}`);
  if (args.task) {
    const lines = boundedLines(args.task, expanded ? 8_000 : 1_200, expanded ? 40 : 6);
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

function snapshotFrom(details: Record<string, unknown>): Record<string, unknown> {
  return details.snapshot && typeof details.snapshot === "object"
    ? details.snapshot as Record<string, unknown>
    : details;
}

function stringField(details: Record<string, unknown>, name: string): string | undefined {
  const direct = details[name];
  if (typeof direct === "string") return direct;
  const snapshot = snapshotFrom(details)[name];
  return typeof snapshot === "string" ? snapshot : undefined;
}

function operationFrom(details: Record<string, unknown>, name: string): Record<string, unknown> | undefined {
  const operation = snapshotFrom(details)[name];
  return operation && typeof operation === "object" ? operation as Record<string, unknown> : undefined;
}

function queuedOperationId(details: Record<string, unknown>): string | undefined {
  const operation = operationFrom(details, "queuedOperation");
  const operationId = operation?.operationId;
  return typeof operationId === "string" ? operationId : undefined;
}

function operationTask(details: Record<string, unknown>, name: string): string | undefined {
  const task = operationFrom(details, name)?.task;
  return typeof task === "string" ? oneLine(task, 120) : undefined;
}

function resultMetadata(
  details: Record<string, unknown>,
  args: SubagentRenderArgs,
  expanded: boolean,
): string {
  const queuedId = queuedOperationId(details);
  const activeTask = args.action === "status" ? operationTask(details, "activeOperation") : undefined;
  const queuedTask = args.action === "status" ? operationTask(details, "queuedOperation") : undefined;
  if (!expanded) {
    const queue = queuedId ? `follow-up queued${queuedTask ? `: ${queuedTask}` : ""}` : "";
    return [activeTask, queue].filter(Boolean).join(" · ");
  }
  const runId = stringField(details, "runId") ?? ("id" in args ? args.id : undefined);
  const operationId = stringField(details, "operationId")
    ?? ("operationId" in args ? args.operationId : undefined)
    ?? ("expectedOperationId" in args ? args.expectedOperationId : undefined);
  const activeOperationId = stringField(details, "activeOperationId");
  const entries: string[] = [];
  if (runId) entries.push(`run ${shownId(runId, expanded)}`);
  if (operationId && operationId !== activeOperationId && operationId !== queuedId) {
    entries.push(`operation ${shownId(operationId, expanded)}`);
  }
  if (activeOperationId) entries.push(`active ${shownId(activeOperationId, expanded)}`);
  if (activeTask) entries.push(`task ${activeTask}`);
  if (queuedId) entries.push(`queued ${shownId(queuedId, expanded)}`);
  if (queuedTask) entries.push(`queued task ${queuedTask}`);
  return entries.join(" · ");
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
  const agent = stringField(details, "agent");
  const subject = agent ? `${agent} ` : "";
  const task = stringField(details, "task");
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
  } else if (action === "start" && (status === "running" || status === "idle")) {
    stopSpinner(state);
    text = theme.fg("accent", `↗ ${subject}started`);
  } else if (action === "wait" && details.reason === "timeout") {
    stopSpinner(state);
    text = theme.fg("warning", `◷ ${subject}still running`);
  } else if (action === "interrupt") {
    stopSpinner(state);
    text = details.accepted === true
      ? theme.fg("warning", "■ Interrupt requested")
      : theme.fg("muted", `• Already ${status ?? "settled"}`);
  } else if (action === "send" && context.args.mode === "steer") {
    stopSpinner(state);
    text = details.accepted === true
      ? theme.fg("accent", "↪ Steering sent")
      : theme.fg("muted", "• Steering not applied");
  } else if (status === "queued" || details.queued === true) {
    stopSpinner(state);
    text = theme.fg("accent", "◷ Follow-up queued");
  } else if (status === "running") {
    stopSpinner(state);
    text = theme.fg("warning", `● ${subject}running`);
  } else if (status === "idle") {
    stopSpinner(state);
    text = theme.fg("accent", `○ ${subject}idle`);
  } else if (status === "failed" || status === "crashed" || status === "cancelled") {
    stopSpinner(state);
    text = theme.fg("error", `✗ ${subject}${status}`);
  } else if (status === "closed") {
    stopSpinner(state);
    text = theme.fg("muted", `• ${subject}closed`);
  } else {
    stopSpinner(state);
    text = theme.fg("success", `✓ ${subject}completed`);
  }

  const metadata = isPartial || action === "list" ? "" : resultMetadata(details, context.args, expanded);
  if (metadata) {
    text += expanded
      ? `\n${theme.fg("muted", `  ${metadata}`)}`
      : theme.fg("muted", ` · ${metadata}`);
  }
  if (expanded && task) {
    text += `\n${theme.fg("dim", `  task: ${oneLine(task, 240)}`)}`;
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
