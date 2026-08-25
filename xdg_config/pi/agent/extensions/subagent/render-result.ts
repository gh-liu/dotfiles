import { type Theme } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

import { collapseHome, formatCountdown, oneLine, type SubagentRenderArgs, type SubagentRenderContext, type SubagentRenderResult, type SubagentRenderState } from "./render-shared.ts";

const SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

function deadlineFrom(args: SubagentRenderArgs): number | undefined {
  if (args.action === "run" || args.action === "start") return args.deadlineMs;
  if (args.action === "send" && args.mode === "follow_up") return args.deadlineMs;
  return undefined;
}

function resultText(result: SubagentRenderResult): string {
  return result.content.find((part) => part.type === "text")?.text ?? "";
}

/** Keep both ends of an over-long string (paths: head dirs matter, tail filename matters). */
function elideMiddle(value: string, max: number): string {
  if (value.length <= max) return value;
  const head = Math.ceil((max - 1) * 0.35);
  const tail = max - 1 - head;
  return `${value.slice(0, head)}…${value.slice(-tail)}`;
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
