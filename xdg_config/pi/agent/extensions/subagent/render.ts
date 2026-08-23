import { type Theme } from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

import { stripModel } from "./protocol.ts";

export const SUBAGENT_COMPLETION_MESSAGE = "subagent-operation-settled";

function formatAgentLabel(agent: string, model?: string, thinking?: string): string {
  const parts = [agent];
  if (model) parts.push(stripModel(model));
  if (thinking) parts.push(thinking);
  return parts.join(" · ");
}

export interface SubagentCompletionDetails {
  /** Session-local short index (#N) assigned at runtime creation, for easy targeting. */
  index?: number;
  runId: string;
  operationId: string;
  agent: string;
  model?: string;
  thinking?: string;
  task: string;
  status: "completed" | "failed" | "interrupted";
  summary: string;
  runtimeStatus: "running" | "idle" | "crashed";
  /** Wall-clock duration of the settled operation in milliseconds, when known. */
  elapsedMs?: number;
}

/** Several background operations settled together and are reported as one card. */
export interface SubagentCompletionBatch {
  batch: SubagentCompletionDetails[];
}

export type SubagentCompletionPayload = SubagentCompletionDetails | SubagentCompletionBatch;

type SubagentRenderArgs =
  | { action: "list" }
  | { action: "run" | "start"; agent: string; task: string; cwd?: string; deadlineMs?: number; model?: string; thinking?: string }
  | { action: "status"; id?: string }
  | { action: "send"; id: string; mode: "follow_up"; message: string; deadlineMs?: number }
  | { action: "send"; id: string; mode: "steer"; message: string; expectedOperationId: string }
  | { action: "wait"; id?: string; operationId?: string; timeoutMs?: number }
  | { action: "interrupt"; id: string; expectedOperationId: string }
  | { action: "close"; id: string };

interface SubagentRenderState {
  spinnerFrame?: number;
  spinnerTimer?: ReturnType<typeof setInterval>;
  /** Wall-clock start of the current execution, captured on first partial render. */
  startedAt?: number;
  /** Immutable per-row runtime identity, learned only from authoritative result details. */
  runtimeIndex?: number;
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

function formatCountdown(ms: number): string {
  // Seconds-only keeps the live view consistent with the title's `· 240s` deadline hint.
  return `${Math.max(0, Math.ceil(ms / 1000))}s`;
}

function deadlineFrom(args: SubagentRenderArgs): number | undefined {
  if (args.action === "run" || args.action === "start") return args.deadlineMs;
  if (args.action === "send" && args.mode === "follow_up") return args.deadlineMs;
  return undefined;
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

// --- Completion notification (custom message) ---
function completionEntryText(
  details: SubagentCompletionDetails,
  { expanded }: { expanded: boolean },
  theme: Theme,
): string {
  const status = details.status ?? "failed";
  const color = status === "completed" ? "success" : status === "interrupted" ? "warning" : "error";
  const marker = status === "completed" ? "✓" : status === "interrupted" ? "■" : "✗";
  const summaryRaw = details.summary ?? "";
  const summaryOneLine = oneLine(summaryRaw, 240);
  let text = `${theme.fg(color, marker)} ${theme.fg(color, status)}`;
  // Short agent name only: the full label (model/thinking) already sits on the tool-call title.
  const agentLabel = `${details.agent}${typeof details.index === "number" ? ` (#${details.index})` : ""}`;
  if (details.agent) text += theme.fg("muted", ` · ${agentLabel}`);
  if (!expanded && details.task) text += theme.fg("muted", ` · ${oneLine(details.task, 80)}`);
  if (!expanded && summaryOneLine) text += `\n${theme.fg("dim", summaryOneLine)}`;
  if (expanded) {
    if (details.task) text += `\n${theme.fg("muted", `  task: ${oneLine(details.task, 240)}`)}`;
    const lines = boundedLines(summaryRaw, 4_000, 20);
    for (const line of lines) if (line) text += `\n${theme.fg("dim", `  ${line}`)}`;
    const elapsed = typeof details.elapsedMs === "number" ? ` · ${formatCountdown(details.elapsedMs)}` : "";
    text += `\n${theme.fg("muted", `  runtime ${details.runtimeStatus}${elapsed}`)}`;
  }
  return text;
}

const completionBg = (status: string | undefined): "toolSuccessBg" | "toolErrorBg" | "toolPendingBg" =>
  status === "completed" ? "toolSuccessBg" : status === "failed" ? "toolErrorBg" : "toolPendingBg";

export function renderSubagentCompletion(
  message: { content: unknown; details?: SubagentCompletionPayload },
  { expanded, outputPad }: { expanded: boolean; outputPad: number },
  theme: Theme,
): Box {
  const raw = message.details;
  const entries: SubagentCompletionDetails[] = !raw
    ? [{ ...({} as SubagentCompletionDetails) }]
    : "batch" in raw ? raw.batch : [raw];
  const box = new Box(outputPad, 0, (value) => theme.bg(completionBg(entries.at(-1)?.status), value));
  entries.forEach((entry, index) => {
    if (index > 0) box.addChild(new Text(theme.fg("muted", "─"), 0, 0));
    box.addChild(new Text(completionEntryText(entry, { expanded }, theme), 0, 0));
  });
  return box;
}

function resultText(result: SubagentRenderResult): string {
  return result.content.find((part) => part.type === "text")?.text ?? "";
}

function shortId(value: string): string {
  return value.length > 12 ? value.slice(0, 8) : value;
}

function shownId(value: string): string {
  return shortId(value);
}

function collapseHome(value: string): string {
  const home = process.env.HOME;
  if (!home || home === "/") return value;
  return value.startsWith(`${home}/`) ? `~${value.slice(home.length)}` : value;
}

/** Keep both ends of an over-long string (paths: head dirs matter, tail filename matters). */
function elideMiddle(value: string, max: number): string {
  if (value.length <= max) return value;
  const head = Math.ceil((max - 1) * 0.35);
  const tail = max - 1 - head;
  return `${value.slice(0, head)}…${value.slice(-tail)}`;
}

// --- Call rendering ---
/** One-line human summary of the work order: strip labels/markdown, first meaningful text. */
function taskTitle(task: string | undefined): string {
  if (!task) return "";
  const firstLine = task
    .split("\n")
    .map((line) => line.trim())
    .find((line) => line.length > 0 && !line.startsWith("#")) ?? "";
  return oneLine(firstLine.replace(/^outcome\s*[:：]\s*/i, ""), 80);
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
  const label = formatAgentLabel(args.agent || "unknown", args.model, args.thinking);
  const title = taskTitle(args.task);
  let text = theme.fg("toolTitle", theme.bold(`${runtimeIndex === undefined ? "" : `#${runtimeIndex} `}${label}`));
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

function positiveSafeRuntimeIndex(value: unknown): number | undefined {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0 ? value : undefined;
}

function runtimeIndexFrom(details: Record<string, unknown>): number | undefined {
  const direct = positiveSafeRuntimeIndex(details.index);
  if (direct !== undefined) return direct;
  const snapshot = details.snapshot;
  return snapshot && typeof snapshot === "object"
    ? positiveSafeRuntimeIndex((snapshot as Record<string, unknown>).index)
    : undefined;
}

function retainRuntimeIndex(
  details: Record<string, unknown>,
  state: SubagentRenderState,
  invalidate: () => void,
): void {
  if (state.runtimeIndex !== undefined) return;
  const runtimeIndex = runtimeIndexFrom(details);
  if (runtimeIndex === undefined) return;
  state.runtimeIndex = runtimeIndex;
  if (state.runtimeIndexInvalidateQueued) return;
  state.runtimeIndexInvalidateQueued = true;
  queueMicrotask(() => {
    state.runtimeIndexInvalidateQueued = false;
    try {
      invalidate();
    } catch {
      // The row may have been disposed before its deferred repaint.
    }
  });
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

function operationTask(details: Record<string, unknown>, name: string): string | undefined {
  const task = operationFrom(details, name)?.task;
  return typeof task === "string" ? oneLine(task, 120) : undefined;
}

function resultMetadata(
  details: Record<string, unknown>,
  args: SubagentRenderArgs,
  expanded: boolean,
): { line: string; transcriptLine?: string } {
  const activeTask = args.action === "status" ? operationTask(details, "activeOperation") : undefined;
  if (!expanded) return { line: activeTask ?? "" };
  // Full run/operation UUIDs are deliberately omitted from the display: the
  // session-local #index identifies runtimes, and the ids remain available in
  // tool responses (status/wait) for programmatic targeting.
  const entries: string[] = [];
  if (activeTask) entries.push(`task ${activeTask}`);
  // Transcript gets its own full-width line: paths are not ids — show the real
  // location ($HOME collapsed, middle elided) instead of clipping to garbage.
  const transcriptPath = (details.transcript as { sessionPath?: string } | undefined)?.sessionPath
    ?? (snapshotFrom(details).transcript as { sessionPath?: string } | undefined)?.sessionPath;
  return {
    line: entries.join(" · "),
    ...(transcriptPath ? { transcriptLine: `transcript ${elideMiddle(collapseHome(transcriptPath), 100)}` } : {}),
  };
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
  const preview = oneLine(output, 240);
  const state = context.state;
  retainRuntimeIndex(details, state, context.invalidate);
  const status = statusFrom(details);
  const action = context.args.action;
  const task = stringField(details, "task");
  if (!expanded && status === "closed" && (action === "close" || action === "status")) {
    stopSpinner(state);
    return new Text("", 0, 0);
  }
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
    const deadlineMs = deadlineFrom(context.args);
    if (deadlineMs !== undefined) {
      // Prefer the authoritative operation start time plumbed from the control plane.
      state.startedAt ??= typeof details.startedAt === "number" ? details.startedAt : Date.now();
      const startedAt = typeof details.startedAt === "number" ? details.startedAt : state.startedAt;
      text += theme.fg("dim", ` ${formatCountdown(deadlineMs - (Date.now() - startedAt))}`);
    }
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
    text = theme.fg("accent", "↗ started");
  } else if (action === "wait" && details.reason === "timeout") {
    stopSpinner(state);
    text = theme.fg("warning", "◷ still running");
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
  } else if (status === "running") {
    stopSpinner(state);
    text = theme.fg("warning", "● running");
  } else if (status === "idle") {
    stopSpinner(state);
    text = theme.fg("accent", "○ idle");
  } else if (status === "failed" || status === "crashed" || status === "cancelled") {
    stopSpinner(state);
    text = theme.fg("error", `✗ ${status}`);
  } else if (status === "closed") {
    stopSpinner(state);
    text = theme.fg("muted", "• closed");
  } else {
    stopSpinner(state);
    text = theme.fg("success", "✓ completed");
  }

  const metadata = isPartial || action === "list"
    ? { line: "" }
    : resultMetadata(details, context.args, expanded);
  const elapsedMs = !isPartial && typeof details.elapsedMs === "number" ? details.elapsedMs : undefined;
  if (elapsedMs !== undefined
    && (action === "run" || action === "wait" || (action === "send" && context.args.mode === "follow_up"))
    && !context.isError) {
    text += theme.fg("dim", ` · ${formatCountdown(elapsedMs)}`);
  }
  if (metadata.line) {
    text += expanded
      ? `\n${theme.fg("muted", `  ${metadata.line}`)}`
      : theme.fg("muted", ` · ${metadata.line}`);
  }
  if (metadata.transcriptLine) {
    text += `\n${theme.fg("muted", `  ${metadata.transcriptLine}`)}`;
  }
  if (expanded && task) {
    text += `\n${theme.fg("dim", `  task: ${oneLine(task, 240)}`)}`;
  }

  const showOutput =
    ((action === "run" || action === "wait") && details.reason !== "timeout")
    || context.isError
    || status === "failed"
    || status === "crashed"
    || status === "cancelled";
  if (action === "list" && output) {
    for (const line of output.split("\n")) text += `\n${theme.fg("dim", line)}`;
  } else if (showOutput && expanded && output) {
    const lines = output.split("\n");
    for (const line of lines.slice(0, 20)) text += `\n${theme.fg("dim", line)}`;
    if (lines.length > 20) text += `\n${theme.fg("muted", "… output truncated in UI")}`;
  } else if (isPartial && preview) {
    const previewColor = /(?:^| )failed;/.test(preview) ? "error" : /(?:^| )completed;/.test(preview) ? "success" : "dim";
    text += theme.fg(previewColor as never, ` — ${preview}`);
  } else if (showOutput && preview) {
    if (status === "completed") text += `\n${theme.fg("dim", preview)}`;
    else text += theme.fg("dim", ` — ${preview}`);
  }
  return new Text(text, 0, 0);
}
