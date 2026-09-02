import { afterEach, vi } from "vitest";
import { mkdtempSync, mkdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import type {
  ExtensionAPI,
  ExtensionContext,
  MessageRenderer,
  ToolDefinition,
} from "@earendil-works/pi-coding-agent";
import {
  buildWakeWordSnippet,
  loadSubagentOverrides,
  registerSubagentExtension,
  validateAuthEnvAllowlist,
} from "../index.ts";
import { SUBAGENT_COMPLETION_MESSAGE } from "../render/index.ts";
import type {
  SubagentController,
  SubagentControllerFactory,
  SubagentOperation,
  SubagentResult,
  SubagentRunOptions,
} from "../protocol.ts";

const temporaryDirectories: string[] = [];

const viWithWaitFor = vi as unknown as { waitFor?: (assertion: () => void | Promise<void>) => Promise<void> };

if (!viWithWaitFor.waitFor) {
  viWithWaitFor.waitFor = async (assertion: () => void | Promise<void>) => {
    const deadline = Date.now() + 1_000;
    let lastError: unknown;
    while (Date.now() < deadline) {
      try {
        await assertion();
        return;
      } catch (error) {
        lastError = error;
        await new Promise((resolve) => setTimeout(resolve, 5));
      }
    }
    if (lastError) throw lastError;
  };
}

afterEach(() => {
  vi.useRealTimers();
  for (const directory of temporaryDirectories.splice(0)) rmSync(directory, { recursive: true, force: true });
});

export function temporaryDirectory(prefix: string): string {
  const directory = mkdtempSync(join(tmpdir(), prefix));
  temporaryDirectories.push(directory);
  return directory;
}

export function writeAgent(directory: string, name = "scout", description = "Inspect files", tools = "read, grep"): void {
  mkdirSync(directory, { recursive: true });
  writeFileSync(
    join(directory, `${name}.md`),
    `---\nname: ${name}\ndescription: ${description}\ntools: [${tools}]\n---\nDo the assigned work.\n`,
  );
}

export function deferred<T>() {
  let resolve!: (value: T | PromiseLike<T>) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}

export interface FakeStart {
  options: SubagentRunOptions;
  accepted: ReturnType<typeof deferred<void>>;
  result: ReturnType<typeof deferred<SubagentResult>>;
}

export class FakeController implements SubagentController {
  readonly starts: FakeStart[] = [];
  readonly interruptCalls: string[] = [];
  private readonly failureEvent = deferred<Error>();
  readonly failure = this.failureEvent.promise;
  closeCalls = 0;
  readonly transcript = { sessionId: "child-session", sessionPath: "/sessions/child.jsonl" };

  constructor(readonly processInstanceId: string, private readonly autoAccept = true) {}

  start(options: SubagentRunOptions): SubagentOperation {
    const call = { options, accepted: deferred<void>(), result: deferred<SubagentResult>() };
    this.starts.push(call);
    if (this.autoAccept) call.accepted.resolve();
    return { accepted: call.accepted.promise, result: call.result.promise };
  }

  async submit(options: SubagentRunOptions): Promise<SubagentResult> {
    const operation = this.start(options);
    await operation.accepted;
    return operation.result;
  }

  async interrupt(expectedOperationId: string): Promise<boolean> {
    this.interruptCalls.push(expectedOperationId);
    const current = [...this.starts].reverse().find(
      (call) => call.options.operationId === expectedOperationId,
    );
    if (!current) return false;
    current.result.resolve(this.makeResult(current, "interrupted", "Interrupted."));
    return true;
  }

  async close(): Promise<void> {
    this.closeCalls += 1;
    for (const call of this.starts) {
      call.accepted.reject(new Error("Controller closed"));
      call.result.reject(new Error("Controller closed"));
    }
  }

  accept(index = this.starts.length - 1): void { this.starts[index].accepted.resolve(); }

  settle(index = this.starts.length - 1, status: SubagentResult["status"] = "completed", summary = "Done."): void {
    const call = this.starts[index];
    call.result.resolve(this.makeResult(call, status, summary));
  }

  fail(error = new Error("Child crashed")): void { this.failureEvent.resolve(error); }

  private makeResult(call: FakeStart, status: SubagentResult["status"], summary: string): SubagentResult {
    return {
      runId: call.options.runId,
      operationId: call.options.operationId,
      processInstanceId: this.processInstanceId,
      agent: call.options.agent.name,
      status,
      summary,
      transcript: this.transcript,
    };
  }
}

export function fakeFactory(autoAccept = true) {
  const controllers: FakeController[] = [];
  const factory = vi.fn<SubagentControllerFactory>(async () => {
    const controller = new FakeController(`process-${controllers.length + 1}`, autoAccept);
    controllers.push(controller);
    return controller;
  });
  return { factory, controllers };
}

export function harness() {
  let tool: ToolDefinition | undefined;
  let shutdown: (() => Promise<void> | void) | undefined;
  const messages: Array<{ message: Record<string, unknown>; options?: Record<string, unknown> }> = [];
  const messageRenderers = new Map<string, MessageRenderer>();
  const pi = {
    registerTool(definition: ToolDefinition) { tool = definition; },
    registerMessageRenderer(customType: string, renderer: MessageRenderer) {
      messageRenderers.set(customType, renderer);
    },
    appendEntry(_customType: string, _data?: unknown) {},
    sendMessage(message: Record<string, unknown>, options?: Record<string, unknown>) {
      messages.push({ message, options });
    },
    on(event: string, handler: () => Promise<void> | void) {
      if (event === "session_shutdown") shutdown = handler;
    },
  } as ExtensionAPI;
  return {
    pi,
    messages,
    messageRenderers,
    getTool: () => tool!,
    shutdown: async () => { await shutdown?.(); },
  };
}

export function context(cwd: string): ExtensionContext {
  return { cwd, sessionManager: { getSessionId: () => "parent-session" } } as unknown as ExtensionContext;
}

export function setup(options: {
  autoAccept?: boolean;
  ids?: string[];
  settingsPath?: string;
  agentNames?: string[];
  maxConcurrentRuns?: number;
} = {}) {
  const root = temporaryDirectory("pi-subagent-project-");
  const agents = temporaryDirectory("pi-subagent-agents-");
  for (const name of options.agentNames ?? ["scout"]) writeAgent(agents, name);
  const fake = fakeFactory(options.autoAccept);
  const extension = harness();
  const ids = options.ids ?? Array.from({ length: 30 }, (_, index) => `id-${index + 1}`);
  const settingsPath = options.settingsPath ?? join(temporaryDirectory("pi-subagent-settings-"), "settings.json");
  if (options.maxConcurrentRuns !== undefined) {
    writeFileSync(settingsPath, JSON.stringify({ subagent: { maxConcurrentRuns: options.maxConcurrentRuns, subagents: {} } }));
  }
  registerSubagentExtension(extension.pi, {
    agentDirectory: agents,
    controllerFactory: fake.factory,
    idFactory: () => ids.shift()!,
    settingsPath,
  });
  const invoke = (params: Record<string, unknown>) => extension.getTool().execute(
    "tool-call",
    params as never,
    undefined, undefined, context(root),
  );
  return { root, agents, fake, extension, invoke };
}

export async function startIdle(env: ReturnType<typeof setup>) {
  const started = await env.invoke({ action: "run", agent: "scout", task: "Initial", background: true });
  const identity = { ref: (started.details as { ref: string }).ref, operationId: env.fake.controllers[0].starts[0].options.operationId, revision: 0 };
  env.fake.controllers[0].settle(0);
  await env.invoke({ action: "get", ref: identity.ref, waitMs: 1_000 });
  return identity;
}

export { buildWakeWordSnippet, loadSubagentOverrides, registerSubagentExtension, SUBAGENT_COMPLETION_MESSAGE, validateAuthEnvAllowlist };
