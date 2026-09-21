import { afterEach, vi } from "vitest";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import type { ExtensionAPI, ExtensionContext, ToolDefinition } from "@earendil-works/pi-coding-agent";
import {
  registerSubagentExtension,
  type ChildHandle,
  type ChildProgress,
  type ChildRequest,
  type ChildResult,
} from "../index.ts";

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { force: true, recursive: true });
  }
});

export function temporaryDirectory(prefix = "pi-subagent-"): string {
  const directory = mkdtempSync(join(tmpdir(), prefix));
  temporaryDirectories.push(directory);
  return directory;
}

export function deferred<T>() {
  let resolve!: (value: T | PromiseLike<T>) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((onResolve, onReject) => {
    resolve = onResolve;
    reject = onReject;
  });
  return { promise, resolve, reject };
}

export class FakeChild implements ChildHandle {
  readonly outcome = deferred<ChildResult>();
  interruptCalls = 0;
  disposeCalls = 0;
  disposeFailure?: Error;
  interruptFailure?: Error;

  constructor(
    readonly request: ChildRequest,
    readonly id: number,
    readonly onProgress?: (progress: ChildProgress) => void,
  ) {}

  get result(): Promise<ChildResult> {
    return this.outcome.promise;
  }

  async interrupt(): Promise<void> {
    this.interruptCalls += 1;
    if (this.interruptFailure) throw this.interruptFailure;
    this.outcome.resolve({ status: "interrupted", error: "Parent cancelled the delegated task." });
  }

  async dispose(): Promise<void> {
    this.disposeCalls += 1;
    if (this.disposeFailure) throw this.disposeFailure;
  }

  complete(handoff = `result-${this.id}`): void {
    this.outcome.resolve({ status: "completed", handoff });
  }

  fail(error = "Provider failed"): void {
    this.outcome.resolve({ status: "failed", error });
  }

  progress(progress: ChildProgress): void {
    this.onProgress?.(progress);
  }
}

export function setup(options: {
  capacity?: number;
  createFailure?: Error;
  beforeCreate?: Promise<void>;
  credentialValues?: string[];
  cwd?: string;
} = {}) {
  const tools = new Map<string, ToolDefinition>();
  let shutdown: (() => Promise<void> | void) | undefined;
  const children: FakeChild[] = [];
  const createChild = vi.fn(async (request: ChildRequest, onProgress?: (progress: ChildProgress) => void) => {
    await options.beforeCreate;
    if (options.createFailure) throw options.createFailure;
    const child = new FakeChild(request, children.length + 1, onProgress);
    children.push(child);
    return child;
  });
  const pi = {
    registerTool(tool: ToolDefinition) {
      tools.set(tool.name, tool);
    },
    on(event: string, handler: () => Promise<void> | void) {
      if (event === "session_shutdown") shutdown = handler;
    },
  } as unknown as ExtensionAPI;

  registerSubagentExtension(pi, {
    capacity: options.capacity ?? 4,
    childFactory: createChild,
    credentialValues: () => options.credentialValues ?? [],
    allowedRoot: options.cwd,
  });

  const cwd = options.cwd ?? temporaryDirectory();
  const context = {
    cwd,
    model: { provider: "parent-provider", id: "parent-model" },
    thinkingLevel: "medium",
    modelRegistry: {
      find(provider: string, id: string) {
        if (provider === "missing") return undefined;
        return { provider, id };
      },
    },
  } as unknown as ExtensionContext;
  const tool = tools.get("subagent")!;

  return {
    children,
    context,
    createChild,
    tool,
    execute(
      params: Record<string, unknown>,
      signal?: AbortSignal,
      contextOverride: Partial<ExtensionContext> = {},
      onUpdate?: (result: unknown) => void,
    ) {
      return tool.execute(
        `call-${children.length + 1}`,
        params as never,
        signal,
        onUpdate as never,
        { ...context, ...contextOverride } as ExtensionContext,
      );
    },
    shutdown: async () => shutdown?.(),
  };
}
