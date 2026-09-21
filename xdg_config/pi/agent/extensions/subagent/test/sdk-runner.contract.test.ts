import { afterEach, describe, expect, test, vi } from "vitest";
import { createSdkChildFactory, type SdkSession } from "../sdk-runner.ts";
import type { ChildRequest } from "../index.ts";

function request(): ChildRequest {
  return {
    task: "Inspect ownership",
    cwd: "/workspace/project",
    guidance: ["Root rule", "Nested rule"],
    model: { provider: "provider", id: "model" } as ChildRequest["model"],
    thinking: "low",
  };
}

function fakeSession() {
  const listeners: Array<(event: unknown) => void> = [];
  const session: SdkSession = {
    subscribe(listener) {
      listeners.push(listener);
      return () => listeners.splice(listeners.indexOf(listener), 1);
    },
    prompt: vi.fn(async () => {
      for (const listener of listeners) {
        listener({
          type: "message_end",
          message: {
            role: "assistant",
            content: [{ type: "text", text: "Plain final handoff" }],
            stopReason: "stop",
          },
        });
        listener({ type: "agent_settled" });
      }
    }),
    abort: vi.fn(async () => {}),
    dispose: vi.fn(),
  };
  return session;
}

describe("SDK child adapter contract", () => {
  afterEach(() => vi.useRealTimers());

  test("waits for authoritative settlement and returns only final assistant prose", async () => {
    const session = fakeSession();
    const createSession = vi.fn(async () => ({ session }));
    const child = await createSdkChildFactory({ createSession })(request());

    expect(await child.result).toEqual({ status: "completed", handoff: "Plain final handoff" });
    expect(session.prompt).toHaveBeenCalledWith(expect.stringContaining("Inspect ownership"));
    expect(session.prompt).toHaveBeenCalledWith(expect.stringContaining("Root rule"));
    expect(createSession).toHaveBeenCalledWith(expect.objectContaining({
      cwd: "/workspace/project",
      thinkingLevel: "low",
      tools: ["read", "grep", "find", "ls", "bash", "edit", "write"],
    }));
    await child.dispose();
    expect(session.dispose).toHaveBeenCalledOnce();
  });

  test("projects thinking and tool lifecycle events without exposing raw reasoning or output", async () => {
    const listeners: Array<(event: unknown) => void> = [];
    const session: SdkSession = {
      subscribe(listener) {
        listeners.push(listener);
        return () => listeners.splice(listeners.indexOf(listener), 1);
      },
      prompt: vi.fn(async () => new Promise<void>(() => {})),
      abort: vi.fn(async () => {}),
      dispose: vi.fn(),
    };
    const progress: Array<{
      activity: string;
      active: Array<{ label: string; status: string }>;
      recent: Array<{ label: string; status: string }>;
    }> = [];
    const child = await createSdkChildFactory({ createSession: async () => ({ session }) })(
      request(),
      (update) => progress.push(update),
    );
    const emit = (event: unknown) => listeners.forEach((listener) => listener(event));

    emit({
      type: "message_update",
      assistantMessageEvent: { type: "thinking_delta", delta: "PRIVATE_REASONING" },
    });
    emit({
      type: "message_end",
      message: { role: "assistant", content: [], stopReason: "toolUse" },
    });
    expect(progress.at(-1)?.activity).toBe("Preparing tool call…");
    emit({
      type: "tool_execution_start",
      toolCallId: "tool-1",
      toolName: "read",
      args: { path: "src/auth.ts" },
    });
    emit({
      type: "tool_execution_end",
      toolCallId: "tool-1",
      toolName: "read",
      result: { content: [{ type: "text", text: "PRIVATE_TOOL_OUTPUT" }] },
      isError: false,
    });

    expect(progress.some((update) => update.activity === "Thinking…")).toBe(true);
    expect(progress.some((update) => update.active.some((item) => item.label === "read src/auth.ts"))).toBe(true);
    expect(progress.at(-1)?.recent).toEqual([
      { kind: "thinking", label: "Thinking", status: "completed" },
      { kind: "tool", label: "read src/auth.ts", status: "completed" },
    ]);
    expect(JSON.stringify(progress)).not.toContain("PRIVATE_REASONING");
    expect(JSON.stringify(progress)).not.toContain("PRIVATE_TOOL_OUTPUT");

    emit({
      type: "message_end",
      message: {
        role: "assistant",
        content: [{ type: "text", text: "Final handoff" }],
        stopReason: "stop",
      },
    });
    emit({ type: "agent_settled" });
    await expect(child.result).resolves.toEqual({ status: "completed", handoff: "Final handoff" });
    await child.dispose();
  });

  test("rejects a non-authoritative or incomplete final response", async () => {
    const session = fakeSession();
    session.prompt = vi.fn(async () => {
      // No agent_settled and no final assistant response.
    });
    const child = await createSdkChildFactory({ createSession: async () => ({ session }) })(request());

    expect(await child.result).toEqual({
      status: "failed",
      error: "Child did not produce a complete final assistant response.",
    });
  });

  test("interrupt and dispose are each idempotent", async () => {
    const session = fakeSession();
    session.prompt = vi.fn(async () => new Promise<void>(() => {}));
    const child = await createSdkChildFactory({ createSession: async () => ({ session }) })(request());

    await Promise.all([child.interrupt(), child.interrupt()]);
    await Promise.all([child.dispose(), child.dispose()]);
    expect(session.abort).toHaveBeenCalledOnce();
    expect(session.dispose).toHaveBeenCalledOnce();
  });

  test("bounds a hung SDK abort and makes cleanup explicitly uncertain", async () => {
    vi.useFakeTimers();
    const session = fakeSession();
    session.prompt = vi.fn(async () => new Promise<void>(() => {}));
    session.abort = vi.fn(async () => new Promise<void>(() => {}));
    const child = await createSdkChildFactory({
      createSession: async () => ({ session }),
      abortTimeoutMs: 25,
    })(request());

    const interrupt = child.interrupt();
    const dispose = child.dispose();
    const interruptExpectation = expect(interrupt).rejects.toThrow("did not finish within 25ms");
    const disposeExpectation = expect(dispose).rejects.toThrow("ownership is uncertain");
    await vi.advanceTimersByTimeAsync(25);

    await interruptExpectation;
    await expect(child.result).resolves.toMatchObject({ status: "interrupted" });
    await disposeExpectation;
    expect(session.dispose).toHaveBeenCalledOnce();
  });
});
