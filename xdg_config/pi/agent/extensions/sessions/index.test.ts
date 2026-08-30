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
} from "./messaging/transport/index.ts";

class FakeTransport implements ActiveSessionTransport {
  readonly sessionId = "self";
  readonly sent: Array<{ to: string; options: ActiveSessionSendOptions }> = [];
  readonly cancelledAsks: string[] = [];
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
  private readonly cancellationHandlers = new Set<(messageId: string) => void>();
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

  cancelAsk(messageId: string): void {
    this.cancelledAsks.push(messageId);
  }

  async disconnect(): Promise<void> {
    this.connected = false;
  }

  onMessage(handler: (from: ActiveSession, message: ActiveSessionMessage) => void): () => void {
    this.messageHandlers.add(handler);
    return () => this.messageHandlers.delete(handler);
  }

  onCancelled(handler: (messageId: string) => void): () => void {
    this.cancellationHandlers.add(handler);
    return () => this.cancellationHandlers.delete(handler);
  }

  onDisconnected(handler: (error: Error) => void): () => void {
    this.disconnectedHandlers.add(handler);
    return () => this.disconnectedHandlers.delete(handler);
  }

  receive(from: ActiveSession, message: ActiveSessionMessage): void {
    this.messageHandlers.forEach((handler) => handler(from, message));
  }

  receiveCancellation(messageId: string): void {
    this.cancellationHandlers.forEach((handler) => handler(messageId));
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

  test("reads a bounded branch-aware history excerpt by session id", async () => {
    vi.spyOn(SessionManager, "listAll").mockResolvedValue([{
      id: "history-1", name: "old", path: "/safe/session.jsonl", cwd: "/work", modified: new Date(1),
      messageCount: 2, firstMessage: "first", allMessagesText: "first second",
    }] as never);
    const entries = [
      { id: "root", parentId: null, type: "message", timestamp: "2020-01-01T00:00:00Z", message: { role: "user", content: "first" } },
      { id: "reply", parentId: "root", type: "message", timestamp: "2020-01-01T00:00:01Z", message: { role: "assistant", content: "second" } },
    ];
    vi.spyOn(SessionManager, "open").mockReturnValue({
      getEntries: () => entries,
      getBranch: (id?: string) => entries.slice(0, id === "reply" ? 2 : 1),
      getEntry: (id: string) => entries.find((entry) => entry.id === id),
      getChildren: (id: string) => entries.filter((entry) => entry.parentId === id),
      buildContextEntries: () => entries,
    } as never);
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => new FakeTransport() });
    const result = await h.tools.get("sessions")!.execute("read", {
      action: "get_entries", sessionId: "history-1", mode: "entries", entryId: "reply", limit: 1,
    }, undefined, undefined, context());
    expect(result.details).toMatchObject({ result: { sessionId: "history-1", entries: [{ id: "reply", text: "second" }] } });
    expect((result.content[0] as { text: string }).text).toContain("history_detail");
  });

  test("rejects history reads outside the current cwd and invalid locators", async () => {
    vi.spyOn(SessionManager, "listAll").mockResolvedValue([{
      id: "other", name: "other", path: "/other/session.jsonl", cwd: "/other", modified: new Date(1),
      messageCount: 0, firstMessage: "", allMessagesText: "",
    }] as never);
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => new FakeTransport() });
    const outside = await h.tools.get("sessions")!.execute("read", { action: "get_entries", sessionId: "other" }, undefined, undefined, context());
    expect(outside.details).toMatchObject({ error: true, code: "INVALID_ARGUMENT" });
    const invalid = await h.tools.get("sessions")!.execute("read", { action: "get_entries", sessionId: "a", path: "/b" }, undefined, undefined, context());
    expect(invalid.details).toMatchObject({ error: true, code: "INVALID_ARGUMENT" });
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
    const model = JSON.parse((result.content[0] as { text: string }).text);
    expect(model.items[0]).toEqual({ sessionId: "peer-1", name: "worker", cwd: "/work", status: "idle", self: false });
    expect(model.items[0]).not.toHaveProperty("model");
    expect(model.items[0]).not.toHaveProperty("lastActivity");
  });

  test("bounds aggregate active-session model output while details stay complete", async () => {
    const transport = new FakeTransport();
    transport.sessions = Array.from({ length: 20 }, (_, index) => ({
      ...transport.sessions[0], id: `peer-${index}`, name: `worker-${index}`, cwd: `/${"c".repeat(5_000)}-${index}`,
    }));
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);
    const result = await h.tools.get("sessions")!.execute("list", { action: "list", limit: 20 }, undefined, undefined, {} as never);
    const text = (result.content[0] as { text: string }).text;
    const model = JSON.parse(text);
    expect(text.length).toBeLessThanOrEqual(16_000);
    expect(model.total).toBe(20);
    expect(model.omitted).toBeGreaterThan(0);
    expect((result.details as any).results).toHaveLength(20);
    expect((result.details as any).results[0].cwd).toHaveLength(5_003);
  });

  test("projects bounded history model fields while details retain full records", async () => {
    const longPath = `/${"p".repeat(5_000)}`;
    vi.spyOn(SessionManager, "listAll").mockResolvedValue([{
      id: "history-1", name: "old", path: longPath, cwd: "/work", modified: new Date(1), messageCount: 3,
      allMessagesText: `before ${"z".repeat(1_000)} needle after`,
    }] as never);
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => new FakeTransport() });
    const result = await h.tools.get("sessions")!.execute("history", { action: "search_history", query: "needle" }, undefined, undefined, {} as never);
    const text = (result.content[0] as { text: string }).text;
    const model = JSON.parse(text);
    expect(text.length).toBeLessThanOrEqual(16_000);
    expect(model.items[0]).not.toHaveProperty("messageCount");
    expect(model.items[0].snippet.length).toBeLessThanOrEqual(242);
    expect(model.items[0].path).toContain("[truncated:");
    expect((result.details as any).results[0]).toMatchObject({ path: longPath, messageCount: 3 });
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
    expect(result.details).toMatchObject({ reply: { content: { text: "Yes" } } });
  });

  test("caps ask replies while details retain the authoritative reply", async () => {
    const transport = new FakeTransport();
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);
    const ask = h.tools.get("session_message")!.execute("call", { action: "ask", to: "worker", message: "?" }, new AbortController().signal, undefined, {} as never);
    await vi.waitFor(() => expect(transport.sent).toHaveLength(1));
    const text = "x".repeat(64 * 1024);
    transport.receive(transport.sessions[0], { id: "reply", timestamp: 1, replyTo: transport.sent[0].options.messageId, content: { text } });
    const result = await ask;
    const model = (result.content[0] as { text: string }).text;
    expect(model.length).toBe(16_000);
    expect(model).toMatch(/\[truncated: \d+ characters omitted\]$/);
    expect((result.details as any).reply.content.text).toBe(text);
  });

  test("caps unsolicited follow-ups while retaining full message details", async () => {
    const transport = new FakeTransport();
    transport.sessions[0].name = "worker-" + "n".repeat(2_000);
    transport.sessions[0].cwd = "/" + "c".repeat(5_000);
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);
    const text = "message-start-" + "y".repeat(64 * 1024 - 14);
    transport.receive(transport.sessions[0], { id: "inbound", timestamp: 1, content: { text } });
    const injected = h.sendMessage.mock.calls[0][0];
    expect(injected.content.length).toBe(16_000);
    expect(injected.content).toContain("[truncated:");
    expect(injected.content).toContain("message-start-");
    expect(injected.details.message.content.text).toBe(text);
    expect(injected.details.from.name).toBe(transport.sessions[0].name);
    expect(injected.details.from.cwd).toBe(transport.sessions[0].cwd);
  });

  test("pending uses bounded valid JSON with omission metadata and full details", async () => {
    const transport = new FakeTransport();
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);
    for (let index = 0; index < 40; index += 1) {
      transport.receive(transport.sessions[0], { id: `ask-${index}`, timestamp: index, expectsReply: true, content: { text: String(index).repeat(64 * 1024) } });
    }
    const result = await h.tools.get("session_message")!.execute("pending", { action: "pending" }, new AbortController().signal, undefined, {} as never);
    const text = (result.content[0] as { text: string }).text;
    const model = JSON.parse(text);
    expect(text.length).toBeLessThanOrEqual(16_000);
    expect(model).toMatchObject({ total: 40, truncated: 40 });
    expect(model.omitted).toBeGreaterThan(0);
    expect(model.items[0].message).toContain("[truncated:");
    expect((result.details as any).pending).toHaveLength(40);
    expect((result.details as any).pending[0].message).toHaveLength(64 * 1024);
  });

  test("releases the ask waiter when sending throws", async () => {
    const transport = new FakeTransport();
    const send = vi.spyOn(transport, "send")
      .mockRejectedValueOnce(new Error("send failed"))
      .mockResolvedValueOnce({ id: "ask-2", delivered: false, reason: "not delivered" });
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);

    const first = await h.tools.get("session_message")!.execute(
      "first",
      { action: "ask", to: "worker", message: "First question", timeoutMs: 5_000 },
      new AbortController().signal,
      undefined,
      {} as never,
    );
    const second = await h.tools.get("session_message")!.execute(
      "second",
      { action: "ask", to: "worker", message: "Second question", timeoutMs: 5_000 },
      new AbortController().signal,
      undefined,
      {} as never,
    );
    h.events.get("session_shutdown")?.();

    expect(first.details).toMatchObject({ error: true, code: "SESSION_MESSAGE_FAILED" });
    expect(second.details).toMatchObject({ error: true, code: "DELIVERY_FAILED" });
    expect(send).toHaveBeenCalledTimes(2);
  });

  test("cancels the broker ask when tool execution is aborted", async () => {
    const transport = new FakeTransport();
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);
    const controller = new AbortController();

    const ask = h.tools.get("session_message")!.execute(
      "call",
      { action: "ask", to: "worker", message: "Are you ready?", timeoutMs: 5_000 },
      controller.signal,
      undefined,
      {} as never,
    );
    await vi.waitFor(() => expect(transport.sent).toHaveLength(1));
    controller.abort();

    const result = await ask;
    expect(result.details).toMatchObject({ error: true, code: "SESSION_MESSAGE_FAILED" });
    expect(transport.cancelledAsks).toEqual([transport.sent[0].options.messageId]);
  });

  test("cancels the broker ask when waiting for a reply times out", async () => {
    const transport = new FakeTransport();
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);

    const result = await h.tools.get("session_message")!.execute(
      "call",
      { action: "ask", to: "worker", message: "Are you ready?", timeoutMs: 10 },
      new AbortController().signal,
      undefined,
      {} as never,
    );

    expect(result.details).toMatchObject({ error: true, code: "SESSION_MESSAGE_FAILED" });
    expect((result.content[0] as { text: string }).text).toBe("No reply within 10ms");
    expect(transport.cancelledAsks).toEqual([transport.sent[0].options.messageId]);
  });

  test("does not send an ask when tool execution is already aborted", async () => {
    const transport = new FakeTransport();
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);
    const controller = new AbortController();
    controller.abort();

    const result = await h.tools.get("session_message")!.execute(
      "call",
      { action: "ask", to: "worker", message: "Are you ready?", timeoutMs: 5_000 },
      controller.signal,
      undefined,
      {} as never,
    );

    expect(result.details).toMatchObject({ error: true, code: "SESSION_MESSAGE_FAILED" });
    expect(transport.sent).toEqual([]);
    expect(transport.cancelledAsks).toEqual([]);
  });

  test("removes a cancelled inbound ask before it can be replied to", async () => {
    const transport = new FakeTransport();
    const h = harness();
    sessionsExtension(h.pi, { createTransport: () => transport });
    await start(h);

    transport.receive(transport.sessions[0], {
      id: "ask-1",
      timestamp: Date.now(),
      expectsReply: true,
      content: { text: "Still needed?" },
    });
    const pendingBefore = await h.tools.get("session_message")!.execute(
      "pending-before",
      { action: "pending" },
      new AbortController().signal,
      undefined,
      {} as never,
    );
    expect(pendingBefore.details).toMatchObject({ pending: [{ messageId: "ask-1" }] });

    transport.receiveCancellation("ask-1");

    const pendingAfter = await h.tools.get("session_message")!.execute(
      "pending-after",
      { action: "pending" },
      new AbortController().signal,
      undefined,
      {} as never,
    );
    expect(pendingAfter.details).toEqual({ pending: [] });
    const reply = await h.tools.get("session_message")!.execute(
      "reply",
      { action: "reply", replyTo: "ask-1", message: "Too late" },
      new AbortController().signal,
      undefined,
      {} as never,
    );
    expect(reply.details).toMatchObject({ error: true, code: "UNKNOWN_MESSAGE" });
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
