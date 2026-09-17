import {
  createAgentSession,
  DefaultResourceLoader,
  getAgentDir,
  SessionManager,
  type AgentSessionEvent,
  type CreateAgentSessionOptions,
} from "@earendil-works/pi-coding-agent";

import type { ChildFactory, ChildHandle, ChildRequest, ChildResult } from "./index.ts";

const CHILD_TOOLS = ["read", "grep", "find", "ls", "bash", "edit", "write"];
const CHILD_SYSTEM_PROMPT = `You are a fresh one-shot child agent. Complete the assigned task in the supplied working directory.

Follow applicable project guidance. Use only the tools provided by the controller. Do not attempt nested delegation. Return concise plain prose with the outcome, evidence, changes, validation, and remaining risks that matter to the parent. Never include credentials, raw reasoning, transcript paths, process IDs, or internal operation IDs.`;

export interface SdkSession {
  subscribe(listener: (event: AgentSessionEvent | unknown) => void): () => void;
  prompt(text: string): Promise<void>;
  abort(): Promise<void>;
  dispose(): void;
}

interface SdkDependencies {
  createSession?: (options: CreateAgentSessionOptions) => Promise<{ session: SdkSession }>;
  abortTimeoutMs?: number;
}

async function abortWithin(session: SdkSession, timeoutMs: number): Promise<void> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    await Promise.race([
      session.abort(),
      new Promise<never>((_resolve, reject) => {
        timer = setTimeout(
          () => reject(new Error(`Child SDK abort did not finish within ${timeoutMs}ms.`)),
          timeoutMs,
        );
      }),
    ]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}

function promptFor(request: ChildRequest): string {
  const guidance = request.guidance.length > 0
    ? `\n\nApplicable project guidance, ordered root to leaf:\n\n${request.guidance.join("\n\n")}`
    : "";
  return `Task:\n${request.task}\n\nWorking directory: ${request.cwd}${guidance}\n\nReturn the final handoff as plain prose. Do not wrap it in JSON.`;
}

function assistantText(message: unknown): { text: string; stopReason?: string } | undefined {
  if (!message || typeof message !== "object") return undefined;
  const value = message as { role?: unknown; content?: unknown; stopReason?: unknown };
  if (value.role !== "assistant" || !Array.isArray(value.content)) return undefined;
  const text = value.content
    .filter((part): part is { type: "text"; text: string } =>
      Boolean(part) && typeof part === "object"
        && (part as { type?: unknown }).type === "text"
        && typeof (part as { text?: unknown }).text === "string")
    .map((part) => part.text)
    .join("\n");
  return { text, ...(typeof value.stopReason === "string" ? { stopReason: value.stopReason } : {}) };
}

export function createSdkChildFactory(dependencies: SdkDependencies = {}): ChildFactory {
  const createSession = dependencies.createSession ?? createAgentSession;
  const abortTimeoutMs = dependencies.abortTimeoutMs ?? 5_000;

  return async (request: ChildRequest): Promise<ChildHandle> => {
    const loader = new DefaultResourceLoader({
      cwd: request.cwd,
      agentDir: getAgentDir(),
      noExtensions: true,
      noSkills: true,
      noPromptTemplates: true,
      noThemes: true,
      noContextFiles: true,
      systemPrompt: CHILD_SYSTEM_PROMPT,
    });
    await loader.reload();
    const { session } = await createSession({
      cwd: request.cwd,
      agentDir: getAgentDir(),
      model: request.model,
      thinkingLevel: request.thinking,
      tools: CHILD_TOOLS,
      resourceLoader: loader,
      sessionManager: SessionManager.inMemory(request.cwd),
    });

    let terminal: ChildResult | undefined;
    let finalAssistant: { text: string; stopReason?: string } | undefined;
    let settled = false;
    let interrupted = false;
    let disposed = false;
    let abortFailure: Error | undefined;
    let interruptPromise: Promise<void> | undefined;
    let disposePromise: Promise<void> | undefined;
    let resolveResult!: (result: ChildResult) => void;
    const result = new Promise<ChildResult>((resolve) => { resolveResult = resolve; });
    const finish = (value: ChildResult) => {
      if (terminal) return;
      terminal = value;
      resolveResult(value);
    };

    const unsubscribe = session.subscribe((event) => {
      if (!event || typeof event !== "object" || !("type" in event)) return;
      if (event.type === "message_end" && "message" in event) {
        const candidate = assistantText(event.message);
        if (candidate) finalAssistant = candidate;
      }
      if (event.type === "agent_settled") {
        settled = true;
        if (interrupted) {
          finish({ status: "interrupted", error: "Parent cancelled the delegated task." });
        } else if (finalAssistant?.stopReason === "stop" && finalAssistant.text.trim()) {
          finish({ status: "completed", handoff: finalAssistant.text });
        } else if (finalAssistant) {
          finish({
            status: "failed",
            error: finalAssistant.text.trim()
              ? `Child stopped with ${finalAssistant.stopReason ?? "an incomplete response"}: ${finalAssistant.text}`
              : "Child did not produce a complete final assistant response.",
          });
        } else {
          finish({ status: "failed", error: "Child did not produce a complete final assistant response." });
        }
      }
    });

    void session.prompt(promptFor(request)).then(() => {
      if (!settled && !terminal) {
        finish({ status: "failed", error: "Child did not produce a complete final assistant response." });
      }
    }, (error: unknown) => {
      finish({ status: "failed", error: error instanceof Error ? error.message : String(error) });
    });

    return {
      result,
      interrupt() {
        if (interruptPromise) return interruptPromise;
        interrupted = true;
        finish({ status: "interrupted", error: "Parent cancelled the delegated task." });
        interruptPromise = abortWithin(session, abortTimeoutMs).catch((error: unknown) => {
          abortFailure = error instanceof Error ? error : new Error(String(error));
          throw abortFailure;
        });
        return interruptPromise;
      },
      dispose() {
        if (disposePromise) return disposePromise;
        disposePromise = Promise.resolve().then(async () => {
          if (disposed) return;
          disposed = true;
          if (interruptPromise) await interruptPromise.catch(() => {});
          unsubscribe();
          session.dispose();
          if (abortFailure) {
            throw new Error(`Child cleanup ownership is uncertain: ${abortFailure.message}`);
          }
        });
        return disposePromise;
      },
    };
  };
}
