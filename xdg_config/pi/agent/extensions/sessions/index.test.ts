import { SessionManager } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI, ExtensionContext, ToolDefinition } from "@earendil-works/pi-coding-agent";
import { afterEach, describe, expect, test, vi } from "vitest";
import sessionsExtension from "./index.ts";
import type {
  ActiveSession,
  ActiveSessionMessage,
  ActiveSessionRegistration,
  ActiveSessionSendOptions,
  ActiveSessionSendResult,
  ActiveSessionTransport,
} from "./transport/index.ts";

class FakeTransport implements ActiveSessionTransport {
  readonly sessionId = "self";
  readonly sent: Array<{ to: string; options: ActiveSessionSendOptions }> = [];
  connected = false;
  sessions: ActiveSession[] = [
    {
      id: "peer-1",
      name: "worker",
      cwd: "/work",
      model: "model",
      pid: 2,
      startedAt: 1,
      lastActivity: 2,
      status: "idle",
    },
  ];
  error: Error | undefined;
  private readonly messageHandlers = new Set<(from: ActiveSession, message: ActiveSessionMessage) => void>();
  private readonly disconnectedHandlers = new Set<(error: Error) => void>();

  async connect(_registration: ActiveSessionRegistration): Promise<void> {
    if (this.error) throw this.error;
    this.connected = true;
  }

  async listSessions(): Promise<ActiveSession[]> {
    if (!this.connected) throw new Error("Not connected");
    return this.sessions;
  }

  async send(to: string, options: ActiveSessionSendOptions): Promise<ActiveSessionSendResult> {
    this.sent.push({ to, options });
    return { id: options.messageId ?? "sent-1", delivered: true };
  }

  async cancel(messageId: string): Promise<ActiveSessionSendResult> {
    return { id: messageId, delivered: true };
  }

  cancelAsk(_messageId: string): void {}

  async disconnect(): Promise<void> {
    this.connected = false;
  }

  onMessage(handler: (from: ActiveSession, message: ActiveSessionMessage) => void): () => void {
    this.messageHandlers.add(handler);
    return () => this.messageHandlers.delete(handler);
  }

  onDisconnected(handler: (error: Error) => void): () => void {
    this.disconnectedHandlers.add(handler);
    return () => this.disconnectedHandlers.delete(handler);
  }

  receive(from: ActiveSession, message: ActiveSessionMessage): void {
    this.messageHandlers.forEach((handler) => handler(from, message));
  }
}

type Harness = {
  pi: ExtensionAPI;
  tools: Map<string, ToolDefinition>;
  events: Map<string, (...args: any[]) => void>;
  sendMessage: ReturnType<typeof vi.fn>;
};

function harness(): Harness {
  const tools = new Map<string, ToolDefinition>();
  const events = new Map<string, (...args: any[]) => void>();
  const sendMessage = vi.fn();
  const pi = {
    registerTool(tool: ToolDefinition) {
      tools.set(tool.name, tool);
    },
    on(event: string, handler: (...args: any[]) => void) {
      events.set(event, handler);
    },
    sendMessage,
  } as unknown as ExtensionAPI;
  return { pi, tools, events, sendMessage };
}

function context(): ExtensionContext {
  return {
    cwd: "/work",
    mode: "rpc",
    hasUI: false,
    model: undefined,
    scopedModels: [],
    signal: undefined,
    sessionManager: {
      getSessionName: () => "self",
      getSessionId: () => "self",
    },
    isIdle: () => true,
  } as unknown as ExtensionContext;
}

async function start(h: Harness, ctx = context()): Promise<void> {
  h.events.get("session_start")?.({}, ctx);
  await Promise.resolve();
  await Promise.resolve();
}

afterEach(() => vi.restoreAllMocks());

describe("sessions transport boundary", () => {
  test("history search works without constructing a transport", async () => {
    const listAll = vi.spyOn(SessionManager, "listAll").mockResolvedValue([]);
    const createTransport = vi.fn(() => new FakeTransport());
    const h = harness();
    sessionsExtension(h.pi, { createTransport });

    const result = await h.tools.get("sessions")!.execute(
      "call",
      { action: "search_history", query: "old message" },
      undefined,
      undefined,
      {} as never,
    );

    expect(listAll).toHaveBeenCalledOnce();
    expect(createTransport).not.toHaveBeenCalled();
    expect((result.content[0] as { text: string }).text).toContain("No sessions matched");
  });

  test("lists active sessions through the transport", async () => {
    const transport = new FakeTransport();
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);

    const result = await h.tools.get("sessions")!.execute(
      "call",
      { action: "list" },
      undefined,
      undefined,
      {} as never,
    );

    expect(result.details).toMatchObject({ results: [{ sessionId: "peer-1", self: false }] });
  });

  test("sends a message through the transport", async () => {
    const transport = new FakeTransport();
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);

    const result = await h.tools.get("session_message")!.execute(
      "call",
      { action: "send", to: "worker", message: "Hello" },
      new AbortController().signal,
      undefined,
      {} as never,
    );

    expect(transport.sent).toEqual([{ to: "peer-1", options: { text: "Hello" } }]);
    expect((result.content[0] as { text: string }).text).toContain("Message sent to worker");
  });

  test("sends and resolves an ask through the transport", async () => {
    const transport = new FakeTransport();
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);

    const send = h.tools.get("session_message")!.execute(
      "call",
      { action: "ask", to: "worker", message: "Are you ready?", timeoutMs: 5_000 },
      new AbortController().signal,
      undefined,
      {} as never,
    );
    await vi.waitFor(() => expect(transport.sent).toHaveLength(1));
    expect(transport.sent[0]?.options).toMatchObject({ text: "Are you ready?", expectsReply: true });
    transport.receive(transport.sessions[0], {
      id: "reply-1",
      timestamp: Date.now(),
      replyTo: transport.sent[0].options.messageId,
      content: { text: "Yes" },
    });

    const result = await send;
    expect((result.content[0] as { text: string }).text).toBe("Yes");
  });

  test("reports unavailable active sessions without affecting history", async () => {
    const transport = new FakeTransport();
    transport.error = new Error("broker unavailable");
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);

    const result = await h.tools.get("sessions")!.execute(
      "call",
      { action: "list" },
      undefined,
      undefined,
      {} as never,
    );

    expect(result.details).toMatchObject({ error: true, code: "INTERCOM_UNAVAILABLE" });
  });
});
