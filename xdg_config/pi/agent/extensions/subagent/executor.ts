import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { dirname, join } from "node:path";
import { StringDecoder } from "node:string_decoder";
import { fileURLToPath } from "node:url";

import { VERSION } from "@earendil-works/pi-coding-agent";
import { boundText, redactSecrets } from "./output.ts";
import { SubagentCancellationError } from "./protocol.ts";
import type { SubagentExecutor, SubagentResult, SubagentRunOptions } from "./protocol.ts";

interface JsonSubagentConfig {
  command?: string;
  commandArgsPrefix?: string[];
  piAgentDirectory?: string;
  terminationGraceMs?: number;
  authEnvAllowlist?: string[];
  toolProviders?: Record<
    string,
    { extensionPaths?: string[]; environmentVariables?: string[] }
  >;
}

type JsonSubagentOptions = SubagentRunOptions & JsonSubagentConfig;

interface JsonEvent {
  type: string;
  hadNonWhitespaceText?: boolean;
  toolName?: string;
  args?: unknown;
  isError?: boolean;
  assistantMessageEvent?: {
    type?: string;
  };
  message?: {
    role?: string;
    content?: Array<{ type?: string; text?: string }>;
    stopReason?: string;
    errorMessage?: string;
  };
  [key: string]: unknown;
}

interface DecoderLimits {
  maxRecordBytes: number;
  maxBufferBytes: number;
}

const BASE_ENVIRONMENT = new Set([
  "HOME",
  "PATH",
  "SHELL",
  "TMPDIR",
  "USER",
  "LOGNAME",
  "TERM",
  "LANG",
  "LANGUAGE",
]);

const MAX_JSONL_BYTES = 1024 * 1024;
const MAX_STDERR_BYTES = 64 * 1024;
const STDERR_TRUNCATION_MARKER = "[truncated]\n";
const STDERR_LONG_LINE_MARKER = "[truncated oversized stderr line]\n";
const SUPPORTED_PI_VERSION = "0.84.1";

class BoundedJsonlDecoder {
  private buffer = Buffer.alloc(0);
  private finished = false;

  constructor(
    private readonly onEvent: (event: JsonEvent) => void,
    private readonly limits: DecoderLimits,
  ) {
    for (const [name, value] of Object.entries(limits)) {
      if (!Number.isSafeInteger(value) || value <= 0) {
        throw new Error(`${name} must be a positive integer`);
      }
    }
  }

  write(chunk: Buffer | Uint8Array): void {
    if (this.finished) throw new Error("Cannot write after JSONL decoder finish");
    this.buffer = Buffer.concat([this.buffer, chunk]);

    let newline = this.buffer.indexOf(0x0a);
    while (newline !== -1) {
      const record = this.buffer.subarray(0, newline);
      this.buffer = this.buffer.subarray(newline + 1);
      this.decodeRecord(record);
      newline = this.buffer.indexOf(0x0a);
    }

    if (
      this.buffer.byteLength > this.limits.maxRecordBytes ||
      this.buffer.byteLength > this.limits.maxBufferBytes
    ) {
      throw new Error("JSONL record or parser buffer exceeds configured limit");
    }
  }

  finish(): void {
    if (this.finished) return;
    this.finished = true;
    if (this.buffer.byteLength > 0) this.decodeRecord(this.buffer);
    this.buffer = Buffer.alloc(0);
  }

  private decodeRecord(record: Buffer): void {
    if (record.byteLength > this.limits.maxRecordBytes) {
      throw new Error("JSONL record exceeds configured limit");
    }
    const normalized = record.at(-1) === 0x0d ? record.subarray(0, -1) : record;
    if (normalized.byteLength === 0) return;

    let value: unknown;
    try {
      value = JSON.parse(normalized.toString("utf8"));
    } catch {
      throw new Error("Malformed JSONL record");
    }
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      throw new Error("Malformed JSONL record: expected an object");
    }
    this.onEvent(value as JsonEvent);
  }
}

function finalAssistantText(
  events: JsonEvent[],
): { text: string; hadNonWhitespaceText: boolean; stopReason?: string; error?: string } | undefined {
  for (let index = events.length - 1; index >= 0; index--) {
    const event = events[index];
    if (event.type !== "message_end" || event.message?.role !== "assistant") continue;
    const text = (event.message.content ?? [])
      .filter((part) => part.type === "text" && typeof part.text === "string")
      .map((part) => part.text as string)
      .join("\n");
    return {
      text,
      hadNonWhitespaceText: event.hadNonWhitespaceText ?? text.trim() !== "",
      stopReason: event.message.stopReason,
      error: event.message.errorMessage,
    };
  }
  return undefined;
}

function buildSubagentResult(
  identity: Pick<SubagentResult, "runId" | "operationId" | "agent">,
  events: JsonEvent[],
): SubagentResult {
  const final = finalAssistantText(events);
  const completed = final?.stopReason === "stop" && final.hadNonWhitespaceText;
  const fallback =
    final?.error || final?.text || "Child exited without a complete final assistant response.";

  return {
    ...identity,
    status: completed ? "completed" : "failed",
    summary: boundText(fallback, { maxCharacters: 32_000, maxLines: 400 }),
    transcript: {},
  };
}

function buildArguments(
  agent: SubagentRunOptions["agent"],
  toolProviders: JsonSubagentConfig["toolProviders"],
): string[] {
  const args = [
    "--mode",
    "json",
    "-p",
    "--no-session",
    "--no-context-files",
    "--no-extensions",
    "--no-skills",
    "--no-prompt-templates",
    "--no-themes",
    "--no-approve",
    "--append-system-prompt",
    "",
    "--tools",
    agent.tools.join(","),
    "--system-prompt",
    agent.systemPrompt,
  ];
  const extensionPaths = [
    ...new Set(
      agent.tools.flatMap((tool) => toolProviders?.[tool]?.extensionPaths ?? []),
    ),
  ];
  for (const extensionPath of extensionPaths) {
    args.push("--extension", extensionPath);
  }
  if (agent.model) args.push("--model", agent.model);
  if (agent.thinking) args.push("--thinking", agent.thinking);
  return args;
}

function pinnedPiInvocation(): { command: string; args: string[] } {
  if (VERSION !== SUPPORTED_PI_VERSION) {
    throw new Error(`Unsupported Pi version: ${VERSION}; expected ${SUPPORTED_PI_VERSION}`);
  }
  const packageEntry = fileURLToPath(import.meta.resolve("@earendil-works/pi-coding-agent"));
  const cliPath = join(dirname(packageEntry), "cli.js");
  return { command: process.execPath, args: [cliPath] };
}

function buildEnvironment(options: JsonSubagentOptions): NodeJS.ProcessEnv {
  const selected = new Set(BASE_ENVIRONMENT);
  for (const name of Object.keys(process.env)) {
    if (name.startsWith("LC_")) selected.add(name);
  }
  const providerEnvironmentVariables = options.agent.tools.flatMap(
    (tool) => options.toolProviders?.[tool]?.environmentVariables ?? [],
  );
  for (const name of [...(options.authEnvAllowlist ?? []), ...providerEnvironmentVariables]) {
    if (!/^[A-Z_][A-Z0-9_]*$/.test(name)) {
      throw new Error(`Invalid authentication environment variable name: ${name}`);
    }
    if (process.env[name] !== undefined && /[\r\n]/.test(process.env[name]!)) {
      throw new Error(`Authentication environment variable must not contain newlines: ${name}`);
    }
    selected.add(name);
  }

  const environment: NodeJS.ProcessEnv = {};
  for (const name of selected) {
    if (process.env[name] !== undefined) environment[name] = process.env[name];
  }
  environment.PI_SUBAGENT_RUN_ID = options.runId;
  environment.PI_SUBAGENT_OPERATION_ID = options.operationId;
  environment.PI_SUBAGENT_PARENT_SESSION_ID = options.parentSessionId;
  environment.PI_SUBAGENT_DEPTH = "1";
  if (options.piAgentDirectory) environment.PI_CODING_AGENT_DIR = options.piAgentDirectory;
  return environment;
}

function signalProcessTree(child: ChildProcessWithoutNullStreams, signal: NodeJS.Signals): void {
  if (child.pid === undefined) return;
  try {
    if (process.platform === "win32") child.kill(signal);
    else process.kill(-child.pid, signal);
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code === "ESRCH") return;
    try {
      child.kill(signal);
    } catch {
      // Process close remains the authoritative cleanup signal.
    }
  }
}

function processGroupExists(pid: number): boolean {
  if (process.platform === "win32") return false;
  try {
    process.kill(-pid, 0);
    return true;
  } catch (error) {
    return (error as NodeJS.ErrnoException).code === "EPERM";
  }
}

async function waitForProcessTreeCleanup(
  child: ChildProcessWithoutNullStreams,
  graceMs: number,
): Promise<void> {
  if (process.platform === "win32" || child.pid === undefined) return;
  const pid = child.pid;
  const deadline = Date.now() + graceMs;
  while (processGroupExists(pid) && Date.now() < deadline) {
    await new Promise((resolve) => setTimeout(resolve, Math.min(25, graceMs)));
  }
  if (!processGroupExists(pid)) return;

  signalProcessTree(child, "SIGKILL");
  const killDeadline = Date.now() + graceMs;
  while (processGroupExists(pid) && Date.now() < killDeadline) {
    await new Promise((resolve) => setTimeout(resolve, Math.min(25, graceMs)));
  }
  if (processGroupExists(pid)) {
    throw new Error("Owned child process group remained alive after SIGKILL");
  }
}

function credentialValues(options: JsonSubagentOptions): string[] {
  return [...new Set((options.authEnvAllowlist ?? [])
    .map((name) => process.env[name])
    .filter((value): value is string => value !== undefined && value.length > 0))]
    .sort((left, right) => right.length - left.length);
}

function appendRetainedStderr(current: string, addition: string): string {
  const wasTruncated = current.startsWith(STDERR_TRUNCATION_MARKER);
  const previous = wasTruncated
    ? current.slice(STDERR_TRUNCATION_MARKER.length)
    : current;
  const merged = `${previous}${addition}`;
  if (!wasTruncated && Buffer.byteLength(merged) <= MAX_STDERR_BYTES) return merged;
  const available = MAX_STDERR_BYTES - Buffer.byteLength(STDERR_TRUNCATION_MARKER);
  const bytes = Buffer.from(merged);
  let start = Math.max(0, bytes.byteLength - available);
  while (start < bytes.byteLength && (bytes[start] & 0xc0) === 0x80) start++;
  return `${STDERR_TRUNCATION_MARKER}${bytes.subarray(start).toString("utf8")}`;
}

function failureResult(options: JsonSubagentOptions, diagnostic: string): SubagentResult {
  return buildSubagentResult(
    { runId: options.runId, operationId: options.operationId, agent: options.agent.name },
    [
      {
        type: "message_end",
        message: {
          role: "assistant",
          content: [{ type: "text", text: diagnostic }],
          stopReason: "error",
          errorMessage: diagnostic,
        },
      },
    ],
  );
}

function safeToolProgress(event: JsonEvent, exactSecretValues: string[]): string {
  const toolName = typeof event.toolName === "string" ? event.toolName : "tool";
  const args = event.args && typeof event.args === "object" && !Array.isArray(event.args)
    ? event.args as Record<string, unknown>
    : {};
  const values = toolName === "grep" ? [args.pattern, args.path] : [args.path];
  const detail = values
    .filter((value): value is string => typeof value === "string" && value.trim() !== "")
    .map((value) => boundText(value.replace(/\s+/g, " ").trim(), { maxCharacters: 80, maxLines: 1 }, exactSecretValues))
    .join(" in ");
  return boundText(`${toolName}${detail ? ` ${detail}` : ""}`, { maxCharacters: 160, maxLines: 1 }, exactSecretValues);
}

async function runJsonSubagent(options: JsonSubagentOptions): Promise<SubagentResult> {
  if (!Number.isSafeInteger(options.deadlineMs) || options.deadlineMs <= 0) {
    throw new Error("deadlineMs must be a positive integer");
  }
  if (
    options.terminationGraceMs !== undefined &&
    (!Number.isSafeInteger(options.terminationGraceMs) || options.terminationGraceMs <= 0)
  ) {
    throw new Error("terminationGraceMs must be a positive integer");
  }
  if (options.signal?.aborted) {
    throw new SubagentCancellationError("Subagent run cancelled before process creation");
  }

  const pinned = pinnedPiInvocation();
  const child = spawn(options.command ?? pinned.command, [...(options.commandArgsPrefix ?? pinned.args), ...buildArguments(options.agent, options.toolProviders)], {
    cwd: options.cwd,
    env: buildEnvironment(options),
    shell: false,
    detached: process.platform !== "win32",
    stdio: ["pipe", "pipe", "pipe"],
  });
  const finalEvents: JsonEvent[] = [];
  let stderr = "";
  let pendingStderr = "";
  let droppingStderrLine = false;
  const stderrDecoder = new StringDecoder("utf8");
  let terminalCause:
    | { kind: "controller_cancellation"; error: SubagentCancellationError }
    | { kind: "protocol_failure"; error: Error }
    | undefined;
  let terminationCleanup: Promise<void> | undefined;
  let terminationCleanupError: Error | undefined;
  let deadline: NodeJS.Timeout | undefined;
  const exactSecretValues = credentialValues(options);
  let lastProgress = "";
  const reportProgress = (summary: string): void => {
    if (summary === lastProgress) return;
    lastProgress = summary;
    options.onProgress?.(summary);
  };

  const decoder = new BoundedJsonlDecoder(
    (event) => {
      if (event.type === "agent_start") {
        reportProgress("Child started; waiting for model…");
      } else if (event.type === "message_update") {
        const updateType = event.assistantMessageEvent?.type;
        if (updateType?.startsWith("thinking_")) reportProgress("Thinking…");
        else if (updateType?.startsWith("text_")) reportProgress("Writing response…");
        else if (updateType?.startsWith("toolcall_")) reportProgress("Preparing tool call…");
      } else if (event.type === "tool_execution_start") {
        reportProgress(`Running ${safeToolProgress(event, exactSecretValues)}…`);
      } else if (event.type === "tool_execution_end") {
        const tool = safeToolProgress(event, exactSecretValues);
        reportProgress(event.isError ? `${tool} failed; reviewing result…` : `${tool} completed; continuing…`);
      }
      if (event.type === "message_end" && event.message?.role === "assistant") {
        const text = event.message.content
          ?.filter((part) => part.type === "text" && typeof part.text === "string")
          .map((part) => part.text)
          .join("\n");
        finalEvents[0] = {
          type: "message_end",
          hadNonWhitespaceText: (text ?? "").trim() !== "",
          message: {
            role: "assistant",
            content: [
              {
                type: "text",
                text: boundText(text ?? "", { maxCharacters: 32_000, maxLines: 400 }, exactSecretValues),
              },
            ],
            stopReason: event.message.stopReason === "stop" ? "stop" : undefined,
            errorMessage: event.message.errorMessage
              ? boundText(event.message.errorMessage, { maxCharacters: 16_000, maxLines: 200 }, exactSecretValues)
              : undefined,
          },
        };
        if (event.message.stopReason === "stop") reportProgress("Finalizing response…");
      }
    },
    { maxRecordBytes: MAX_JSONL_BYTES, maxBufferBytes: MAX_JSONL_BYTES },
  );

  const terminate = (reason: SubagentCancellationError | Error): void => {
    if (terminalCause) return;
    terminalCause =
      reason instanceof SubagentCancellationError
        ? { kind: "controller_cancellation", error: reason }
        : { kind: "protocol_failure", error: reason };
    if (deadline) clearTimeout(deadline);
    signalProcessTree(child, "SIGTERM");
    terminationCleanup ??= waitForProcessTreeCleanup(child, options.terminationGraceMs ?? 5_000).catch((error) => {
      terminationCleanupError = error instanceof Error ? error : new Error(String(error));
    });
  };
  const onAbort = () => terminate(new SubagentCancellationError("Subagent run cancelled by controller"));
  options.signal?.addEventListener("abort", onAbort, { once: true });
  if (options.signal?.aborted) onAbort();
  deadline = setTimeout(
    () => terminate(new SubagentCancellationError(`Subagent execution deadline exceeded (${options.deadlineMs} ms)`)),
    options.deadlineMs,
  );

  const onStdout = (chunk: Buffer) => {
    if (terminalCause?.kind === "protocol_failure") return;
    try {
      decoder.write(chunk);
    } catch (error) {
      terminate(error instanceof Error ? error : new Error(String(error)));
    }
  };
  const onStderr = (chunk: Buffer) => {
    pendingStderr += stderrDecoder.write(chunk);
    if (droppingStderrLine) {
      const newline = pendingStderr.indexOf("\n");
      if (newline === -1) {
        pendingStderr = "";
        return;
      }
      pendingStderr = pendingStderr.slice(newline + 1);
      droppingStderrLine = false;
    }
    const lastNewline = pendingStderr.lastIndexOf("\n");
    if (lastNewline !== -1) {
      const complete = pendingStderr.slice(0, lastNewline + 1);
      pendingStderr = pendingStderr.slice(lastNewline + 1);
      stderr = appendRetainedStderr(stderr, redactSecrets(complete, exactSecretValues));
    }
    if (Buffer.byteLength(pendingStderr) > MAX_STDERR_BYTES) {
      pendingStderr = "";
      droppingStderrLine = true;
      stderr = appendRetainedStderr(stderr, STDERR_LONG_LINE_MARKER);
    }
  };
  child.stdout.on("data", onStdout);
  child.stderr.on("data", onStderr);
  child.stdin.on("error", (error: NodeJS.ErrnoException) => {
    if (error.code !== "EPIPE") terminate(error);
  });

  const exit = new Promise<{ code: number | null; spawnError?: Error }>((resolve) => {
    let spawnError: Error | undefined;
    child.once("error", (error) => {
      spawnError = error;
    });
    child.once("close", (code) => resolve({ code, spawnError }));
  });

  child.stdin.end(
    JSON.stringify({
      version: 1,
      runtime: {
        runId: options.runId,
        operationId: options.operationId,
        parentSessionId: options.parentSessionId,
        depth: 1,
      },
      workOrder: options.workOrder,
    }),
  );

  const exited = await exit;
  if (deadline) clearTimeout(deadline);
  if (terminationCleanup) await terminationCleanup;
  if (terminationCleanupError && terminalCause?.kind === "controller_cancellation") {
    terminalCause.error = new SubagentCancellationError(
      `${terminalCause.error.message}; process cleanup failed: ${terminationCleanupError.message}`,
    );
  }
  pendingStderr += stderrDecoder.end();
  stderr = appendRetainedStderr(stderr, redactSecrets(pendingStderr, exactSecretValues));
  options.signal?.removeEventListener("abort", onAbort);
  child.stdout.removeListener("data", onStdout);
  child.stderr.removeListener("data", onStderr);

  if (!terminalCause) {
    try {
      decoder.finish();
    } catch (error) {
      terminalCause = {
        kind: "protocol_failure",
        error: error instanceof Error ? error : new Error(String(error)),
      };
    }
  }
  if (terminalCause?.kind === "controller_cancellation") throw terminalCause.error;
  if (terminalCause?.kind === "protocol_failure") {
    return failureResult(options, `Child protocol failure: ${terminalCause.error.message}`);
  }
  if (exited.spawnError) return failureResult(options, `Child process failed to start: ${exited.spawnError.message}`);
  if (exited.code !== 0) {
    const diagnostic = boundText(stderr, { maxCharacters: 16_000, maxLines: 200 }, exactSecretValues);
    return failureResult(options, diagnostic || `Child process exited with code ${String(exited.code)}`);
  }
  return buildSubagentResult(
    { runId: options.runId, operationId: options.operationId, agent: options.agent.name },
    finalEvents,
  );
}

export function createJsonSubagentExecutor(config: JsonSubagentConfig = {}): SubagentExecutor {
  return (options) => runJsonSubagent({ ...options, ...config });
}
