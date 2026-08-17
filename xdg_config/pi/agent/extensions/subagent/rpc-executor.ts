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
import type { SubagentController, SubagentExecutor, SubagentOperation, SubagentResult, SubagentRunOptions } from "./protocol.ts";

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
const SUPPORTED_PI_VERSION = /^0\.84\.(0|[1-9]\d*)$/;

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

export function assertSupportedPiVersion(): void {
  if (!SUPPORTED_PI_VERSION.test(VERSION)) {
    throw new Error(`Unsupported Pi version: ${VERSION}; expected 0.84.x`);
  }
}

function pinnedPiInvocation(): { command: string; args: string[] } {
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
    transcript: { ...transcript },
  };
}

function deferred<T>(): { promise: Promise<T>; resolve: (value: T) => void; reject: (error: Error) => void } {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((next, fail) => { resolve = next; reject = fail; });
  return { promise, resolve, reject };
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

/** Lower-level reusable runtime primitive. One controller owns exactly one RPC process. */
export type RpcSubagentController = SubagentController;

export async function createRpcSubagentController(
  initial: SubagentRunOptions,
  config: RpcSubagentConfig = {},
): Promise<RpcSubagentController> {
  const base: RpcOptions = {
    ...initial,
    agent: { ...initial.agent, tools: [...initial.agent.tools] },
    ...config,
  };
  if (base.terminationGraceMs !== undefined && (!Number.isSafeInteger(base.terminationGraceMs) || base.terminationGraceMs <= 0)) {
    throw new Error("terminationGraceMs must be a positive integer");
  }
  if (initial.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before process creation");
  const processInstanceId = randomUUID();
  const sessionRoot = base.sessionRoot ?? join(tmpdir(), "pi-subagent-sessions");
  await mkdir(sessionRoot, { recursive: true });
  if (initial.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before process creation");
  const sessionDirectory = await mkdtemp(join(sessionRoot, "run-"));
  if (initial.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before process creation");
  const pinned = pinnedPiInvocation();
  if (initial.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before process creation");
  const child = spawn(
    base.command ?? pinned.command,
    [...(base.commandArgsPrefix ?? pinned.args), ...buildArguments(base, sessionDirectory)],
    { cwd: base.cwd, env: buildEnvironment(base), shell: false, detached: process.platform !== "win32", stdio: ["pipe", "pipe", "pipe"] },
  );
  const secrets = credentialValues(base);
  let stderr = "";
  let pendingStderr = "";
  let droppingStderrLine = false;
  const stderrDecoder = new StringDecoder("utf8");
  let spawnError: Error | undefined;
  let closed = false;
  let forcedClose = false;
  let closing: Promise<void> | undefined;
  let active = false;
  let activeAccepted = false;
  let activeOperationId: string | undefined;
  let abortActive: ((message: string) => Promise<boolean>) | undefined;
  let fatal: Error | undefined;
  const controllerFailure = deferred<Error>();
  let transcript: SubagentResult["transcript"] | undefined;
  let finalized = false;
  let currentRecord: ((record: RpcRecord) => void) | undefined;
  let activeTerminal: ReturnType<typeof deferred<never>> | undefined;
  const responses = new Map<string, ReturnType<typeof deferred<RpcResponse>>>();
  const exit = new Promise<{ code: number | null }>((resolveExit) => {
    child.once("error", (error) => { spawnError = error; });
    child.once("close", (code) => resolveExit({ code }));
  });
  const terminate = (error: Error): void => {
    if (fatal) return;
    fatal = error;
    controllerFailure.resolve(error);
    activeTerminal?.reject(error);
    for (const waiter of responses.values()) waiter.reject(error);
    signalProcessTree(child, "SIGTERM");
  };
  const decoder = new BoundedJsonlDecoder((record) => {
    try {
      if (record.type === "response") {
        if (typeof record.id !== "string" || typeof record.command !== "string" || typeof record.success !== "boolean") throw new Error("Malformed RPC response");
        const waiter = responses.get(record.id);
        if (!waiter) throw new Error(`Unexpected RPC response id: ${record.id}`);
        waiter.resolve(record as RpcResponse);
      } else currentRecord?.(record);
    } catch (error) { terminate(error instanceof Error ? error : new Error(String(error))); }
  });
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
      stderr = appendStderr(stderr, redactSecrets(pendingStderr.slice(0, lastNewline + 1), secrets));
      pendingStderr = pendingStderr.slice(lastNewline + 1);
    }
    if (Buffer.byteLength(pendingStderr) > MAX_STDERR_BYTES) {
      pendingStderr = "";
      droppingStderrLine = true;
      stderr = appendStderr(stderr, STDERR_LONG_LINE_MARKER);
    }
  };
  const onStdinError = (error: NodeJS.ErrnoException): void => { if (error.code !== "EPIPE") terminate(error); };
  child.stdout.on("data", onStdout);
  child.stderr.on("data", onStderr);
  child.stdin.on("error", onStdinError);
  exit.then(() => {
    if (!closed) terminate(spawnError ?? new Error("RPC child process exited unexpectedly"));
  });

  const request = async (
    idPrefix: string,
    command: string,
    data: Record<string, unknown> = {},
  ): Promise<RpcResponse> => {
    if (fatal) throw fatal;
    if (closed) throw new Error("RPC subagent controller is closed");
    const id = `${idPrefix}:${command}:${randomUUID()}`;
    const waiter = deferred<RpcResponse>();
    responses.set(id, waiter);
    try {
      child.stdin.write(JSON.stringify({ id, type: command, ...data }) + "\n");
      const response = await waiter.promise;
      if (response.command !== command || !response.success) throw new Error(`RPC command failed: ${command}`);
      return response;
    } finally {
      responses.delete(id);
    }
  };

  const finalize = (): void => {
    if (finalized) return;
    finalized = true;
    pendingStderr += stderrDecoder.end();
    stderr = appendStderr(stderr, redactSecrets(pendingStderr, secrets));
    child.stdout.removeListener("data", onStdout);
    child.stderr.removeListener("data", onStderr);
    child.stdin.removeListener("error", onStdinError);
    decoder.finish();
  };

  const close = (): Promise<void> => {
    if (closing) return closing;
    closed = true;
    if (active) {
      forcedClose = true;
      const error = new Error("RPC subagent controller closed during active operation");
      activeTerminal?.reject(error);
      for (const waiter of responses.values()) waiter.reject(error);
      signalProcessTree(child, "SIGTERM");
    }
    closing = (async () => {
      child.stdin.end();
      let closeTimer: NodeJS.Timeout | undefined;
      let leader: { code: number | null };
      try {
        leader = await Promise.race([
          exit,
          new Promise<never>((_, reject) => { closeTimer = setTimeout(() => {
          signalProcessTree(child, "SIGTERM");
          reject(new Error("Child did not exit after RPC controller close"));
          }, base.terminationGraceMs ?? 5_000); }),
        ]);
      } catch (error) {
        await waitForProcessTreeCleanup(child, base.terminationGraceMs ?? 5_000);
        await exit;
        throw error;
      } finally {
        if (closeTimer) clearTimeout(closeTimer);
      }
      // Leader exit is not sufficient: detached descendants share the owned group.
      if (child.pid !== undefined && processGroupExists(child.pid)) signalProcessTree(child, "SIGTERM");
      await waitForProcessTreeCleanup(child, base.terminationGraceMs ?? 5_000);
      finalize();
      if (fatal) throw fatal;
      if (spawnError) throw new Error(`Child process failed to start: ${spawnError.message}`);
      if (leader.code !== 0 && !forcedClose) throw new Error(stderr || `Child process exited with code ${String(leader.code)}`);
    })().finally(finalize);
    return closing;
  };

  return {
    processInstanceId,
    get transcript() { return { ...(transcript ?? {}) }; },
    failure: controllerFailure.promise,
    start(options): SubagentOperation {
      const accepted = deferred<void>();
      let operationBegan = false;
      const resultPromise = (async (): Promise<SubagentResult> => {
      if (closed) throw new Error("RPC subagent controller is closed");
      if (active) throw new Error("RPC subagent controller already has an active operation");
      if (fatal) throw fatal;
      const identityMismatch = options.runId !== base.runId
        || options.parentSessionId !== base.parentSessionId
        || options.cwd !== base.cwd
        || options.agent.name !== base.agent.name
        || options.agent.systemPrompt !== base.agent.systemPrompt
        || options.agent.model !== base.agent.model
        || options.agent.thinking !== base.agent.thinking
        || options.agent.tools.length !== base.agent.tools.length
        || options.agent.tools.some((tool, index) => tool !== base.agent.tools[index]);
      if (identityMismatch) throw new Error("RPC subagent runtime identity does not match controller");
      if (!Number.isSafeInteger(options.deadlineMs) || options.deadlineMs <= 0) throw new Error("deadlineMs must be a positive integer");
      if (options.signal?.aborted) throw new SubagentCancellationError("Subagent run cancelled before submission");
      active = true;
      operationBegan = true;
      activeOperationId = options.operationId;
      const terminal = deferred<never>();
      terminal.promise.catch(() => {});
      activeTerminal = terminal;
      // Every reducer below is operation-local and therefore reset on every submit.
      let finalText: { text: string; stopReason?: string; error?: string } | undefined;
      const settled = deferred<void>();
      let authoritativeSettled = false;
      let abortResponseReceived = false;
      let abortWatchdog: NodeJS.Timeout | undefined;
      const clearAbortWatchdog = (): void => {
        if (!authoritativeSettled || !abortResponseReceived || !abortWatchdog) return;
        clearTimeout(abortWatchdog);
        abortWatchdog = undefined;
      };
      const activeTools = new Map<string, string>();
      let lastProgress = "";
      const report = (text: string): void => {
        const bounded = boundedOneLine(text, 160, secrets);
        if (bounded !== lastProgress) options.onProgress?.(lastProgress = bounded);
      };
      currentRecord = (record) => {
        if (record.type === "agent_start") report("Child started; waiting for model…");
        else if (record.type === "message_update") {
          const type = record.assistantMessageEvent?.type;
          if (type?.startsWith("thinking_")) report("Thinking…");
          else if (type?.startsWith("toolcall_")) report("Preparing tool call…");
          else if (type?.startsWith("text_")) report("Writing response…");
        } else if (record.type === "tool_execution_start") {
          const label = safeToolProgress(record, secrets);
          if (typeof record.toolCallId === "string") activeTools.set(record.toolCallId, label);
          report(label.endsWith("…") ? label : `${label}…`);
        } else if (record.type === "tool_execution_end") {
          const label = typeof record.toolCallId === "string" ? activeTools.get(record.toolCallId) ?? safeToolProgress(record, secrets) : safeToolProgress(record, secrets);
          if (typeof record.toolCallId === "string") activeTools.delete(record.toolCallId);
          report(record.isError ? `${label} failed; reviewing result…` : `${label} completed; continuing…`);
        } else if (record.type === "message_end" && record.message?.role === "assistant") {
          const text = (record.message.content ?? []).filter((part) => part.type === "text" && typeof part.text === "string").map((part) => part.text as string).join("\n");
          finalText = { text: boundText(text, { maxCharacters: 32_000, maxLines: 400 }, secrets), stopReason: record.message.stopReason, error: record.message.errorMessage };
          if (record.message.stopReason === "stop") report("Finalizing response…");
        } else if (record.type === "agent_settled") {
          authoritativeSettled = true;
          settled.resolve();
          clearAbortWatchdog();
        }
      };
      let interrupted: SubagentCancellationError | undefined;
      let cancellationRequest: Promise<void> | undefined;
      const cancel = async (error: SubagentCancellationError): Promise<boolean> => {
        if (interrupted || authoritativeSettled || activeOperationId !== options.operationId) return false;
        interrupted = error;
        abortWatchdog = setTimeout(() => {
          terminate(new Error("RPC abort did not reach authoritative settlement"));
        }, base.terminationGraceMs ?? 5_000);
        cancellationRequest = request(options.operationId, "abort").then(() => {
          abortResponseReceived = true;
          clearAbortWatchdog();
        }).catch((abortError) => {
          terminate(abortError instanceof Error ? abortError : new Error(String(abortError)));
          throw abortError;
        });
        await cancellationRequest;
        return true;
      };
      const onAbort = () => {
        void cancel(new SubagentCancellationError("Subagent run cancelled by controller")).catch(() => {});
      };
      let deadline: NodeJS.Timeout | undefined;
      try {
        if (!transcript) {
          const state = await request(options.operationId, "get_state");
          const data = state.data as { sessionId?: unknown; sessionFile?: unknown } | undefined;
          if (!data || typeof data.sessionId !== "string" || data.sessionId.length === 0 || typeof data.sessionFile !== "string" || data.sessionFile.length === 0) throw new Error("get_state response did not contain session identity");
          const sessionPath = resolve(data.sessionFile);
          const relativePath = relative(resolve(sessionDirectory), sessionPath);
          if (!isAbsolute(sessionPath) || relativePath.startsWith("..") || relativePath.includes("/..")) throw new Error("RPC session file escaped the managed session directory");
          transcript = { sessionId: data.sessionId, sessionPath };
        }
        await request(options.operationId, "prompt", { message: ["Execute this work order exactly as provided. Return only the requested handoff.", JSON.stringify(options.workOrder, null, 2)].join("\n\n") });
        activeAccepted = true;
        accepted.resolve();
        abortActive = (message) => cancel(new SubagentCancellationError(message));
        options.signal?.addEventListener("abort", onAbort, { once: true });
        deadline = setTimeout(() => {
          void cancel(new SubagentCancellationError(`Subagent execution deadline exceeded (${options.deadlineMs} ms)`)).catch(() => {});
        }, options.deadlineMs);
        if (options.signal?.aborted) onAbort();
        await Promise.race([settled.promise, terminal.promise]);
        if (cancellationRequest) await cancellationRequest;
        if (fatal) throw fatal;
        if (interrupted) return result({ ...base, ...options }, "interrupted", interrupted.message, transcript, secrets, processInstanceId);
        const complete = finalText?.stopReason === "stop" && finalText.text.trim() !== "";
        return result({ ...base, ...options }, complete ? "completed" : "failed", finalText?.error || finalText?.text || "Child did not produce a complete final assistant response.", transcript, secrets, processInstanceId);
      } catch (error) {
        const failure = error instanceof Error ? error : new Error(String(error));
        accepted.reject(failure);
        if (operationBegan && !closed) terminate(failure);
        throw failure;
      } finally {
        if (deadline) clearTimeout(deadline);
        if (abortWatchdog) clearTimeout(abortWatchdog);
        options.signal?.removeEventListener("abort", onAbort);
        currentRecord = undefined;
        if (activeTerminal === terminal) activeTerminal = undefined;
        active = false;
        activeAccepted = false;
        if (activeOperationId === options.operationId) activeOperationId = undefined;
        abortActive = undefined;
      }
      })();
      accepted.promise.catch(() => {});
      void resultPromise.catch((error) => accepted.reject(error instanceof Error ? error : new Error(String(error))));
      return { accepted: accepted.promise, result: resultPromise };
    },
    submit(options): Promise<SubagentResult> { return this.start(options).result; },
    async steer(expectedOperationId, message): Promise<boolean> {
      if (activeOperationId !== expectedOperationId || !active || !activeAccepted) return false;
      await request(expectedOperationId, "steer", { message });
      return true;
    },
    async interrupt(expectedOperationId): Promise<boolean> {
      if (activeOperationId !== expectedOperationId || !abortActive) return false;
      return abortActive("Subagent operation interrupted by controller");
    },
    close,
  };
}

export function createRpcSubagentExecutor(config: RpcSubagentConfig = {}): SubagentExecutor {
  return async (options) => {
    let controller: RpcSubagentController;
    try {
      controller = await createRpcSubagentController(options, config);
    } catch (error) {
      if (error instanceof SubagentCancellationError) throw error;
      const configured = { ...options, ...config };
      return result(
        configured,
        "failed",
        error instanceof Error ? error.message : String(error),
        {},
        credentialValues(configured),
        randomUUID(),
      );
    }
    let value: SubagentResult;
    try {
      value = await controller.submit(options);
    } catch (error) {
      const operationMessage = error instanceof Error ? error.message : String(error);
      let cleanupMessage: string | undefined;
      try { await controller.close(); } catch (cleanupError) {
        const message = cleanupError instanceof Error ? cleanupError.message : String(cleanupError);
        if (message !== operationMessage) cleanupMessage = message;
      }
      const summary = cleanupMessage
        ? `${operationMessage}\n\nChild process cleanup failed: ${cleanupMessage}`
        : operationMessage;
      if (error instanceof SubagentCancellationError) throw new SubagentCancellationError(summary);
      return result({ ...options, ...config }, "failed", summary, controller.transcript, credentialValues({ ...options, ...config }), controller.processInstanceId);
    }
    try {
      await controller.close();
    } catch (error) {
      return result({ ...options, ...config }, "failed", `Child process cleanup failed: ${error instanceof Error ? error.message : String(error)}`, value.transcript, credentialValues({ ...options, ...config }), controller.processInstanceId);
    }
    if (value.status === "interrupted") throw new SubagentCancellationError(value.summary);
    return value;
  };
}
