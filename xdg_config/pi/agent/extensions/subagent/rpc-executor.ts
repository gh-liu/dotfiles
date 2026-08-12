import { randomUUID } from "node:crypto";
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { mkdir, mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";
import { StringDecoder } from "node:string_decoder";
import { fileURLToPath } from "node:url";

import { VERSION } from "@earendil-works/pi-coding-agent";
import { boundText, redactSecrets } from "./output.ts";
import { SubagentCancellationError } from "./protocol.ts";
import type { SubagentExecutor, SubagentResult, SubagentRunOptions } from "./protocol.ts";

export interface RpcSubagentConfig {
  command?: string;
  commandArgsPrefix?: string[];
  sessionRoot?: string;
  piAgentDirectory?: string;
  terminationGraceMs?: number;
  authEnvAllowlist?: string[];
  toolProviders?: Record<string, { extensionPaths?: string[]; environmentVariables?: string[] }>;
}

type RpcOptions = SubagentRunOptions & RpcSubagentConfig;
type RpcRecord = {
  type: string;
  id?: string;
  command?: string;
  success?: boolean;
  data?: unknown;
  event?: string;
  toolCallId?: string;
  toolName?: string;
  args?: unknown;
  isError?: boolean;
  assistantMessageEvent?: { type?: string };
  message?: {
    role?: string;
    content?: Array<{ type?: string; text?: string }>;
    stopReason?: string;
    errorMessage?: string;
  };
  [key: string]: unknown;
};

type RpcResponse = RpcRecord & { type: "response"; id: string; command: string };

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

  constructor(private readonly onRecord: (record: RpcRecord) => void) {}

  write(chunk: Buffer | Uint8Array): void {
    if (this.finished) throw new Error("Cannot write after JSONL decoder finish");
    this.buffer = Buffer.concat([this.buffer, chunk]);
    let newline = this.buffer.indexOf(0x0a);
    while (newline !== -1) {
      const record = this.buffer.subarray(0, newline);
      this.buffer = this.buffer.subarray(newline + 1);
      this.decode(record);
      newline = this.buffer.indexOf(0x0a);
    }
    if (this.buffer.byteLength > MAX_JSONL_BYTES) {
      throw new Error("JSONL record or parser buffer exceeds configured limit");
    }
  }

  finish(): void {
    if (this.finished) return;
    this.finished = true;
    if (this.buffer.byteLength > 0) this.decode(this.buffer);
    this.buffer = Buffer.alloc(0);
  }

  private decode(record: Buffer): void {
    if (record.byteLength > MAX_JSONL_BYTES) throw new Error("JSONL record exceeds configured limit");
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
    if (typeof (value as { type?: unknown }).type !== "string") {
      throw new Error("Malformed JSONL record: missing type");
    }
    this.onRecord(value as RpcRecord);
  }
}

function pinnedPiInvocation(): { command: string; args: string[] } {
  if (VERSION !== SUPPORTED_PI_VERSION) {
    throw new Error(`Unsupported Pi version: ${VERSION}; expected ${SUPPORTED_PI_VERSION}`);
  }
  const packageEntry = fileURLToPath(import.meta.resolve("@earendil-works/pi-coding-agent"));
  return {
    command: process.execPath,
    args: [join(dirname(packageEntry), "cli.js")],
  };
}

function buildArguments(
  options: RpcOptions,
  sessionDirectory: string,
): string[] {
  const args = [
    "--mode",
    "rpc",
    "--session-dir",
    sessionDirectory,
    "--no-context-files",
    "--no-extensions",
    "--no-skills",
    "--no-prompt-templates",
    "--no-themes",
    "--no-approve",
    "--append-system-prompt",
    "",
    "--tools",
    options.agent.tools.join(","),
    "--system-prompt",
    options.agent.systemPrompt,
  ];
  const extensionPaths = [
    ...new Set(options.agent.tools.flatMap((tool) => options.toolProviders?.[tool]?.extensionPaths ?? [])),
  ];
  for (const extensionPath of extensionPaths) args.push("--extension", extensionPath);
  if (options.agent.model) args.push("--model", options.agent.model);
  if (options.agent.thinking) args.push("--thinking", options.agent.thinking);
  return args;
}

function buildEnvironment(options: RpcOptions): NodeJS.ProcessEnv {
  const selected = new Set(BASE_ENVIRONMENT);
  for (const name of Object.keys(process.env)) if (name.startsWith("LC_")) selected.add(name);
  const providerVariables = options.agent.tools.flatMap(
    (tool) => options.toolProviders?.[tool]?.environmentVariables ?? [],
  );
  for (const name of [...(options.authEnvAllowlist ?? []), ...providerVariables]) {
    if (!/^[A-Z_][A-Z0-9_]*$/.test(name)) throw new Error(`Invalid authentication environment variable name: ${name}`);
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
    if ((error as NodeJS.ErrnoException).code === "ESRCH") return;
    try { child.kill(signal); } catch { /* close remains authoritative */ }
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

async function waitForProcessTreeCleanup(child: ChildProcessWithoutNullStreams, graceMs: number): Promise<void> {
  if (process.platform === "win32" || child.pid === undefined) return;
  const pid = child.pid;
  const until = Date.now() + graceMs;
  while (processGroupExists(pid) && Date.now() < until) await new Promise((resolve) => setTimeout(resolve, 25));
  if (!processGroupExists(pid)) return;
  signalProcessTree(child, "SIGKILL");
  const killUntil = Date.now() + graceMs;
  while (processGroupExists(pid) && Date.now() < killUntil) await new Promise((resolve) => setTimeout(resolve, 25));
  if (processGroupExists(pid)) throw new Error("Owned child process group remained alive after SIGKILL");
}

function appendStderr(current: string, addition: string): string {
  const truncated = current.startsWith(STDERR_TRUNCATION_MARKER);
  const previous = truncated ? current.slice(STDERR_TRUNCATION_MARKER.length) : current;
  const merged = previous + addition;
  if (!truncated && Buffer.byteLength(merged) <= MAX_STDERR_BYTES) return merged;
  const available = MAX_STDERR_BYTES - Buffer.byteLength(STDERR_TRUNCATION_MARKER);
  const bytes = Buffer.from(merged);
  let start = Math.max(0, bytes.byteLength - available);
  while (start < bytes.byteLength && (bytes[start] & 0xc0) === 0x80) start++;
  return STDERR_TRUNCATION_MARKER + bytes.subarray(start).toString("utf8");
}

function credentialValues(options: RpcOptions): string[] {
  const names = [
    ...(options.authEnvAllowlist ?? []),
    ...options.agent.tools.flatMap((tool) => options.toolProviders?.[tool]?.environmentVariables ?? []),
  ];
  return [...new Set(names
    .map((name) => process.env[name])
    .filter((value): value is string => value !== undefined && value.length > 0))]
    .sort((a, b) => b.length - a.length);
}

function identity(
  options: RpcOptions,
  processInstanceId: string,
): Pick<SubagentResult, "runId" | "operationId" | "agent" | "processInstanceId"> {
  return {
    runId: options.runId,
    operationId: options.operationId,
    agent: options.agent.name,
    processInstanceId,
  };
}

function result(
  options: RpcOptions,
  status: SubagentResult["status"],
  summary: string,
  transcript: SubagentResult["transcript"],
  secrets: string[],
  processInstanceId: string,
): SubagentResult {
  return {
    ...identity(options, processInstanceId),
    status,
    summary: boundText(summary, { maxCharacters: 32_000, maxLines: 400 }, secrets),
    transcript,
  };
}

function deferred<T>(): { promise: Promise<T>; resolve: (value: T) => void } {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((next) => { resolve = next; });
  return { promise, resolve };
}

function boundedOneLine(text: string, maxCharacters: number, secrets: string[]): string {
  const normalized = redactSecrets(text, secrets).replace(/\s+/g, " ").trim();
  return normalized.length <= maxCharacters
    ? normalized
    : `${normalized.slice(0, maxCharacters - 1)}…`;
}

function safeToolProgress(record: RpcRecord, secrets: string[]): string {
  const toolName = typeof record.toolName === "string" ? record.toolName : "tool";
  const args = record.args && typeof record.args === "object" && !Array.isArray(record.args)
    ? record.args as Record<string, unknown>
    : {};
  const values = toolName === "grep" ? [args.pattern, args.path] : [args.path];
  const detail = values
    .filter((value): value is string => typeof value === "string" && value.trim() !== "")
    .map((value) => boundedOneLine(value, 80, secrets))
    .join(" · ");
  return boundedOneLine(`${toolName}${detail ? ` ${detail}` : ""}`, 120, secrets);
}

async function runRpcSubagent(options: RpcOptions): Promise<SubagentResult> {
  if (!Number.isSafeInteger(options.deadlineMs) || options.deadlineMs <= 0) throw new Error("deadlineMs must be a positive integer");
  if (options.terminationGraceMs !== undefined && (!Number.isSafeInteger(options.terminationGraceMs) || options.terminationGraceMs <= 0)) {
    throw new Error("terminationGraceMs must be a positive integer");
  }
  if (options.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before process creation");

  const processInstanceId = randomUUID();
  const sessionRoot = options.sessionRoot ?? join(tmpdir(), "pi-subagent-sessions");
  await mkdir(sessionRoot, { recursive: true });
  const sessionDirectory = await mkdtemp(join(sessionRoot, "run-"));
  const pinned = pinnedPiInvocation();
  const child = spawn(
    options.command ?? pinned.command,
    [...(options.commandArgsPrefix ?? pinned.args), ...buildArguments(options, sessionDirectory)],
    { cwd: options.cwd, env: buildEnvironment(options), shell: false, detached: process.platform !== "win32", stdio: ["pipe", "pipe", "pipe"] },
  );
  const secrets = credentialValues(options);
  let stderr = "";
  let pendingStderr = "";
  let droppingStderrLine = false;
  const stderrDecoder = new StringDecoder("utf8");
  let finalText: { text: string; stopReason?: string; error?: string } | undefined;
  let settled = false;
  let terminalCause: { kind: "cancel" | "protocol"; error: Error } | undefined;
  let cleanup: Promise<void> | undefined;
  let cleanupError: Error | undefined;
  let deadline: NodeJS.Timeout | undefined;
  const settledWaiter = deferred<void>();
  const responses = new Map<string, ReturnType<typeof deferred<RpcResponse>>>();
  const activeTools = new Map<string, string>();
  let lastProgress = "";
  const reportProgress = (summary: string): void => {
    const bounded = boundedOneLine(summary, 160, secrets);
    if (bounded === lastProgress) return;
    lastProgress = bounded;
    options.onProgress?.(bounded);
  };

  let spawnError: Error | undefined;
  const exit = new Promise<{ code: number | null }>((resolve) => {
    child.once("error", (error) => { spawnError = error; });
    child.once("close", (code) => resolve({ code }));
  });
  const cleanUpProcessTree = (): void => {
    if (cleanup) return;
    signalProcessTree(child, "SIGTERM");
    cleanup = waitForProcessTreeCleanup(child, options.terminationGraceMs ?? 5_000).catch((failure) => {
      cleanupError = failure instanceof Error ? failure : new Error(String(failure));
    });
  };
  const terminate = (error: Error): void => {
    if (terminalCause) return;
    terminalCause = {
      kind: error instanceof SubagentCancellationError ? "cancel" : "protocol",
      error,
    };
    if (deadline) clearTimeout(deadline);
    cleanUpProcessTree();
  };

  const failIfTerminated = (): void => {
    if (terminalCause) throw terminalCause.error;
  };
  const onRecord = (record: RpcRecord): void => {
    if (terminalCause) return;
    if (record.type === "response") {
      if (typeof record.id !== "string" || typeof record.command !== "string" || typeof record.success !== "boolean") {
        throw new Error("Malformed RPC response");
      }
      const waiter = responses.get(record.id);
      if (!waiter) throw new Error(`Unexpected RPC response id: ${record.id}`);
      waiter.resolve(record as RpcResponse);
    } else if (record.type === "agent_start") {
      reportProgress("Child started; waiting for model…");
    } else if (record.type === "message_update") {
      const updateType = record.assistantMessageEvent?.type;
      if (updateType?.startsWith("thinking_")) reportProgress("Thinking…");
      else if (updateType?.startsWith("toolcall_")) reportProgress("Preparing tool call…");
      else if (updateType?.startsWith("text_")) reportProgress("Writing response…");
    } else if (record.type === "tool_execution_start") {
      const label = safeToolProgress(record, secrets);
      if (typeof record.toolCallId === "string") activeTools.set(record.toolCallId, label);
      reportProgress(label.endsWith("…") ? label : `${label}…`);
    } else if (record.type === "tool_execution_end") {
      const label = typeof record.toolCallId === "string"
        ? activeTools.get(record.toolCallId) ?? safeToolProgress(record, secrets)
        : safeToolProgress(record, secrets);
      if (typeof record.toolCallId === "string") activeTools.delete(record.toolCallId);
      reportProgress(record.isError ? `${label} failed; reviewing result…` : `${label} completed; continuing…`);
    } else if (record.type === "agent_settled") {
      settled = true;
      settledWaiter.resolve();
    } else if (record.type === "message_end" && record.message?.role === "assistant") {
      const text = (record.message.content ?? [])
        .filter((part) => part.type === "text" && typeof part.text === "string")
        .map((part) => part.text as string)
        .join("\n");
      finalText = {
        text: boundText(text, { maxCharacters: 32_000, maxLines: 400 }, secrets),
        stopReason: record.message.stopReason,
        error: record.message.errorMessage,
      };
      if (record.message.stopReason === "stop") reportProgress("Finalizing response…");
    }
  };
  const decoder = new BoundedJsonlDecoder(onRecord);
  const onStdout = (chunk: Buffer): void => {
    try { decoder.write(chunk); } catch (error) { terminate(error instanceof Error ? error : new Error(String(error))); }
  };
  const onStderr = (chunk: Buffer): void => {
    pendingStderr += stderrDecoder.write(chunk);
    if (droppingStderrLine) {
      const newline = pendingStderr.indexOf("\n");
      if (newline === -1) { pendingStderr = ""; return; }
      pendingStderr = pendingStderr.slice(newline + 1);
      droppingStderrLine = false;
    }
    const lastNewline = pendingStderr.lastIndexOf("\n");
    if (lastNewline !== -1) {
      const complete = pendingStderr.slice(0, lastNewline + 1);
      pendingStderr = pendingStderr.slice(lastNewline + 1);
      stderr = appendStderr(stderr, redactSecrets(complete, secrets));
    }
    if (Buffer.byteLength(pendingStderr) > MAX_STDERR_BYTES) {
      pendingStderr = "";
      droppingStderrLine = true;
      stderr = appendStderr(stderr, STDERR_LONG_LINE_MARKER);
    }
  };
  const onStdinError = (error: NodeJS.ErrnoException): void => {
    if (error.code !== "EPIPE") terminate(error);
  };
  child.stdout.on("data", onStdout);
  child.stderr.on("data", onStderr);
  child.stdin.on("error", onStdinError);
  const onAbort = (): void => terminate(new SubagentCancellationError("Subagent run cancelled by controller"));
  options.signal?.addEventListener("abort", onAbort, { once: true });
  deadline = setTimeout(() => terminate(new SubagentCancellationError(`Subagent execution deadline exceeded (${options.deadlineMs} ms)`)), options.deadlineMs);
  if (options.signal?.aborted) onAbort();

  const transcript: SubagentResult["transcript"] = {};
  const request = async (id: string, command: string, data: Record<string, unknown> = {}): Promise<RpcResponse> => {
    const waiter = deferred<RpcResponse>();
    responses.set(id, waiter);
    child.stdin.write(JSON.stringify({ id, type: command, ...data }) + "\n");
    const response = await Promise.race([
      waiter.promise,
      exit.then(() => { throw new Error(`Child exited before RPC response to ${command}`); }),
    ]);
    responses.delete(id);
    failIfTerminated();
    if (response.command !== command) throw new Error(`Unexpected RPC response command: ${response.command}`);
    if (!response.success) throw new Error(`RPC command failed: ${command}`);
    return response;
  };

  let operationError: Error | undefined;
  try {
    const state = await request("get-state", "get_state");
    if (!state.data || typeof state.data !== "object" || Array.isArray(state.data)) throw new Error("get_state response did not contain state data");
    const stateData = state.data as { sessionId?: unknown; sessionFile?: unknown };
    if (typeof stateData.sessionId !== "string" || stateData.sessionId.length === 0 || typeof stateData.sessionFile !== "string" || stateData.sessionFile.length === 0) {
      throw new Error("get_state response did not contain session identity");
    }
    const sessionPath = resolve(stateData.sessionFile);
    const sessionRelativePath = relative(resolve(sessionDirectory), sessionPath);
    if (!isAbsolute(sessionPath) || sessionRelativePath.startsWith("..") || sessionRelativePath.includes("/..")) {
      throw new Error("RPC session file escaped the managed session directory");
    }
    transcript.sessionId = stateData.sessionId;
    transcript.sessionPath = sessionPath;
    await request("prompt", "prompt", {
      message: [
        "Execute this work order exactly as provided. Return only the requested handoff.",
        JSON.stringify(options.workOrder, null, 2),
      ].join("\n\n"),
    });
    failIfTerminated();
    if (!settled) await Promise.race([settledWaiter.promise, exit.then(() => { throw new Error("Child exited before agent_settled"); })]);
    failIfTerminated();
    child.stdin.end();
  } catch (error) {
    operationError = error instanceof Error ? error : new Error(String(error));
    if (!terminalCause) terminate(operationError);
  }

  const exited = await exit;
  if (deadline) clearTimeout(deadline);
  if (child.pid !== undefined && processGroupExists(child.pid)) cleanUpProcessTree();
  if (cleanup) await cleanup;
  pendingStderr += stderrDecoder.end();
  stderr = appendStderr(stderr, redactSecrets(pendingStderr, secrets));
  options.signal?.removeEventListener("abort", onAbort);
  child.stdout.removeListener("data", onStdout);
  child.stderr.removeListener("data", onStderr);
  child.stdin.removeListener("error", onStdinError);
  if (!terminalCause) {
    try { decoder.finish(); } catch (error) { terminalCause = { kind: "protocol", error: error instanceof Error ? error : new Error(String(error)) }; }
  }
  if (terminalCause?.kind === "cancel") {
    if (cleanupError) throw new SubagentCancellationError(`${terminalCause.error.message}; process cleanup failed: ${cleanupError.message}`);
    throw terminalCause.error;
  }
  if (cleanupError) return result(options, "failed", `Child process cleanup failed: ${cleanupError.message}`, transcript, secrets, processInstanceId);
  if (terminalCause?.kind === "protocol") return result(options, "failed", `Child protocol failure: ${terminalCause.error.message}`, transcript, secrets, processInstanceId);
  if (spawnError) return result(options, "failed", `Child process failed to start: ${spawnError.message}`, transcript, secrets, processInstanceId);
  if (operationError) return result(options, "failed", operationError.message, transcript, secrets, processInstanceId);
  if (exited.code !== 0) return result(options, "failed", stderr || `Child process exited with code ${String(exited.code)}`, transcript, secrets, processInstanceId);
  if (!settled || !finalText) return result(options, "failed", finalText?.error || finalText?.text || "Child exited without a complete final assistant response.", transcript, secrets, processInstanceId);
  const completed = finalText.stopReason === "stop" && finalText.text.trim() !== "";
  return result(options, completed ? "completed" : "failed", finalText.error || finalText.text || "Child did not produce a complete final assistant response.", transcript, secrets, processInstanceId);
}

export function createRpcSubagentExecutor(config: RpcSubagentConfig = {}): SubagentExecutor {
  return (options) => runRpcSubagent({ ...options, ...config });
}
