import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { SessionManager } from "@earendil-works/pi-coding-agent";
import { randomUUID } from "node:crypto";
import { Type } from "typebox";
import { createLocalIpcTransport } from "./transport/local-ipc.ts";
import type {
  ActiveSession,
  ActiveSessionMessage,
  ActiveSessionRegistration,
  ActiveSessionSendResult,
  ActiveSessionTransport,
  ActiveSessionTransportFactory,
} from "./transport/index.ts";

const MAX_RESULTS = 20;
const MAX_SNIPPET_LENGTH = 240;
const ASK_TIMEOUT_MS = 10 * 60 * 1000;

type SessionsInput = {
  action: "search_history" | "list";
  query?: string;
  cwd?: string;
  limit?: number;
};

type SessionMessageInput = {
  action: "send" | "ask" | "reply" | "pending" | "cancel";
  to?: string;
  message?: string;
  replyTo?: string;
  messageId?: string;
  timeoutMs?: number;
};

type ToolDetails = {
  error?: boolean;
  code?: string;
  [key: string]: unknown;
};

type ReplyWaiter = {
  messageId: string;
  resolve: (message: ActiveSessionMessage) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
  cleanup: () => void;
};

function snippet(text: string, query: string): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  const position = normalized.toLocaleLowerCase().indexOf(query.toLocaleLowerCase());
  if (position < 0) return normalized.slice(0, MAX_SNIPPET_LENGTH);

  const start = Math.max(0, position - 80);
  const end = Math.min(normalized.length, position + query.length + 160);
  return `${start > 0 ? "…" : ""}${normalized.slice(start, end)}${end < normalized.length ? "…" : ""}`;
}

function errorResult(message: string, code: string) {
  return {
    content: [{ type: "text" as const, text: message }],
    details: { error: true, code } as ToolDetails,
  };
}

function sessionRegistration(ctx: ExtensionContext): ActiveSessionRegistration {
  return {
    name: ctx.sessionManager.getSessionName(),
    cwd: ctx.cwd,
    model: ctx.model?.id ?? "unknown",
    pid: process.pid,
    startedAt: Date.now(),
    lastActivity: Date.now(),
    status: ctx.isIdle() ? "idle" : "thinking",
  };
}

function formatActiveSession(session: ActiveSession, currentId: string | null) {
  return {
    kind: "active" as const,
    instanceId: session.id,
    sessionId: session.id,
    name: session.name,
    cwd: session.cwd,
    model: session.model,
    status: session.status ?? "unknown",
    lastActivity: new Date(session.lastActivity).toISOString(),
    self: session.id === currentId,
  };
}

export type SessionsExtensionOptions = {
  createTransport?: ActiveSessionTransportFactory;
};

export default function sessionsExtension(pi: ExtensionAPI, options: SessionsExtensionOptions = {}): void {
  let context: ExtensionContext | null = null;
  let transport: ActiveSessionTransport | null = null;
  let connectPromise: Promise<ActiveSessionTransport> | null = null;
  let transportCleanup: (() => void)[] = [];
  let replyWaiter: ReplyWaiter | null = null;
  const createTransport = options.createTransport ?? createLocalIpcTransport;
  const pendingInbound = new Map<string, { from: ActiveSession; message: ActiveSessionMessage }>();

  const rejectWaiter = (error: Error) => {
    if (!replyWaiter) return;
    clearTimeout(replyWaiter.timer);
    const waiter = replyWaiter;
    replyWaiter = null;
    waiter.cleanup();
    waiter.reject(error);
  };

  const handleIncoming = (from: ActiveSession, message: ActiveSessionMessage) => {
    if (replyWaiter && message.replyTo === replyWaiter.messageId) {
      const waiter = replyWaiter;
      clearTimeout(waiter.timer);
      replyWaiter = null;
      waiter.cleanup();
      waiter.resolve(message);
      return;
    }

    if (message.expectsReply) pendingInbound.set(message.id, { from, message });
    if (!context) return;

    const replyHint = message.expectsReply
      ? `\n\nReply with session_message({ action: "reply", replyTo: ${JSON.stringify(message.id)}, message: "..." })`
      : "";
    pi.sendMessage(
      {
        customType: "session_message",
        content: `**From ${from.name ?? from.id}** (${from.cwd})${replyHint}\n\n${message.content.text}`,
        display: true,
        details: { from, message },
      },
      { triggerTurn: true, deliverAs: "followUp" },
    );
  };

  const ensureClient = async (): Promise<ActiveSessionTransport> => {
    if (transport) return transport;
    if (connectPromise) return connectPromise;
    if (!context) throw new Error("Session context is not ready");

    const next = createTransport();
    transportCleanup = [
      next.onMessage(handleIncoming),
      next.onCancelled((messageId) => pendingInbound.delete(messageId)),
      next.onDisconnected((error) => {
        if (transport === next) {
          transport = null;
          transportCleanup.forEach((cleanup) => cleanup());
          transportCleanup = [];
        }
        rejectWaiter(error);
      }),
    ];
    connectPromise = (async () => {
      await next.connect(sessionRegistration(context!), context!.sessionManager.getSessionId());
      transport = next;
      return next;
    })();

    try {
      return await connectPromise;
    } catch (error) {
      transportCleanup.forEach((cleanup) => cleanup());
      transportCleanup = [];
      throw error;
    } finally {
      connectPromise = null;
    }
  };

  const disconnect = () => {
    rejectWaiter(new Error("Session communication disconnected"));
    pendingInbound.clear();
    transportCleanup.forEach((cleanup) => cleanup());
    transportCleanup = [];
    const active = transport;
    transport = null;
    if (active) void active.disconnect();
  };

  pi.on("session_start", (_event, ctx) => {
    context = ctx;
    void ensureClient().catch(() => {
      // History search remains available when local IPC is unavailable.
    });
  });
  pi.on("session_shutdown", () => {
    disconnect();
    context = null;
  });

  pi.registerTool({
    name: "sessions",
    label: "Sessions",
    description: "Search local Pi session history or list active Pi sessions reachable through local IPC.",
    parameters: Type.Object({
      action: Type.Union([
        Type.Literal("search_history"),
        Type.Literal("list"),
      ]),
      query: Type.Optional(Type.String({ description: "Text to search for (search_history only)" })),
      cwd: Type.Optional(Type.String({ description: "Working-directory filter" })),
      limit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_RESULTS })),
    }),
    async execute(_toolCallId, input: SessionsInput) {
      const limit = Math.min(input.limit ?? 10, MAX_RESULTS);
      const cwd = input.cwd?.trim();

      if (input.action === "list") {
        try {
          const active = await ensureClient();
          const currentId = active.sessionId;
          const peers = (await active.listSessions())
            .filter((session) => !cwd || session.cwd === cwd || session.cwd.startsWith(`${cwd}/`))
            .slice(0, limit)
            .map((session) => formatActiveSession(session, currentId));
          return {
            content: [{ type: "text" as const, text: peers.length ? JSON.stringify(peers, null, 2) : "No active sessions found." }],
            details: { results: peers },
          };
        } catch (error) {
          return errorResult(`Active sessions unavailable: ${error instanceof Error ? error.message : String(error)}`, "INTERCOM_UNAVAILABLE");
        }
      }

      const query = input.query?.trim() ?? "";
      if (!query) return errorResult("query must not be empty", "INVALID_QUERY");
      const sessions = await SessionManager.listAll();
      const matches = sessions
        .filter((session) => !cwd || session.cwd === cwd || session.cwd.startsWith(`${cwd}/`))
        .map((session) => ({ session, position: session.allMessagesText.toLocaleLowerCase().indexOf(query.toLocaleLowerCase()) }))
        .filter((item) => item.position >= 0)
        .sort((a, b) => b.session.modified.getTime() - a.session.modified.getTime())
        .slice(0, limit)
        .map(({ session }) => ({
          kind: "history" as const,
          sessionId: session.id,
          name: session.name,
          path: session.path,
          cwd: session.cwd,
          modified: session.modified.toISOString(),
          messageCount: session.messageCount,
          snippet: snippet(session.allMessagesText, query),
        }));

      return {
        content: [{ type: "text" as const, text: matches.length ? JSON.stringify(matches, null, 2) : `No sessions matched ${JSON.stringify(query)}.` }],
        details: { query, results: matches },
      };
    },
  });

  pi.registerTool({
    name: "session_message",
    label: "Session Message",
    description: "Send a message to, ask, or reply to an active Pi session through local IPC.",
    parameters: Type.Object({
      action: Type.Union([
        Type.Literal("send"),
        Type.Literal("ask"),
        Type.Literal("reply"),
        Type.Literal("pending"),
        Type.Literal("cancel"),
      ]),
      to: Type.Optional(Type.String({ description: "Target active session name or id" })),
      message: Type.Optional(Type.String({ description: "Message text" })),
      replyTo: Type.Optional(Type.String({ description: "Inbound message id for reply" })),
      messageId: Type.Optional(Type.String({ description: "Previously sent message id for cancellation" })),
      timeoutMs: Type.Optional(Type.Integer({ minimum: 1000, maximum: ASK_TIMEOUT_MS })),
    }),
    async execute(_toolCallId, input: SessionMessageInput, signal) {
      try {
        const active = await ensureClient();
        if (input.action === "pending") {
          const pending = [...pendingInbound.values()].map(({ from, message }) => ({
            from: from.name ?? from.id,
            fromId: from.id,
            messageId: message.id,
            message: message.content.text,
          }));
          return { content: [{ type: "text" as const, text: JSON.stringify(pending, null, 2) }], details: { pending } };
        }
        if (input.action === "cancel") {
          if (!input.messageId) return errorResult("messageId is required", "INVALID_ARGUMENT");
          const result = await active.cancel(input.messageId);
          return result.delivered
            ? { content: [{ type: "text" as const, text: `Cancellation requested for ${input.messageId}` }], details: result as unknown as ToolDetails }
            : errorResult(result.reason ?? "Cancellation was not delivered", "DELIVERY_FAILED");
        }
        if (!input.message) return errorResult("message is required", "INVALID_ARGUMENT");
        if (input.action === "reply") {
          const replyTo = input.replyTo ?? [...pendingInbound.keys()][0];
          if (!replyTo) return errorResult("replyTo is required when there is no pending inbound ask", "NO_PENDING_ASK");
          const target = pendingInbound.get(replyTo);
          if (!target) return errorResult(`Unknown inbound message: ${replyTo}`, "UNKNOWN_MESSAGE");
          const result = await active.send(target.from.id, { text: input.message, replyTo });
          if (!result.delivered) return errorResult(result.reason ?? "Reply was not delivered", "DELIVERY_FAILED");
          pendingInbound.delete(replyTo);
          return { content: [{ type: "text" as const, text: `Reply sent to ${target.from.name ?? target.from.id}` }], details: result as unknown as ToolDetails };
        }
        if (!input.to) return errorResult("to is required", "INVALID_ARGUMENT");
        const sessions = await active.listSessions();
        const target = sessions.find((session) => session.id === input.to || session.name === input.to || session.id.startsWith(input.to!));
        if (!target) return errorResult(`Active session not found: ${input.to}`, "TARGET_NOT_FOUND");
        if (target.id === active.sessionId) return errorResult("Cannot message the current session", "SELF_TARGET");

        if (input.action === "send") {
          const result = await active.send(target.id, { text: input.message });
          return result.delivered
            ? { content: [{ type: "text" as const, text: `Message sent to ${target.name ?? target.id}` }], details: result as unknown as ToolDetails }
            : errorResult(result.reason ?? "Message was not delivered", "DELIVERY_FAILED");
        }

        if (replyWaiter) return errorResult("Already waiting for a reply", "ASK_IN_PROGRESS");
        const messageId = randomUUID();
        const timeoutMs = input.timeoutMs ?? ASK_TIMEOUT_MS;
        let sent = false;
        const answer = new Promise<ActiveSessionMessage>((resolve, reject) => {
          const onAbort = () => {
            if (replyWaiter?.messageId !== messageId) return;
            rejectWaiter(new Error("Ask cancelled"));
            if (sent) active.cancelAsk(messageId);
          };
          const timer = setTimeout(() => {
            if (replyWaiter?.messageId === messageId) {
              rejectWaiter(new Error(`No reply within ${timeoutMs}ms`));
              active.cancelAsk(messageId);
            }
          }, timeoutMs);
          replyWaiter = {
            messageId,
            resolve,
            reject,
            timer,
            cleanup: () => signal.removeEventListener("abort", onAbort),
          };
          signal.addEventListener("abort", onAbort, { once: true });
          if (signal.aborted) onAbort();
        });
        // The answer can be cancelled while transport.send() is still pending.
        // Attach a handler now so that rejection is not reported as unhandled before it is awaited below.
        void answer.catch(() => undefined);
        if (signal.aborted) return await answer;
        let result: ActiveSessionSendResult;
        try {
          const send = active.send(target.id, { text: input.message, expectsReply: true, messageId });
          sent = true;
          result = await send;
        } catch (error) {
          rejectWaiter(error instanceof Error ? error : new Error(String(error)));
          await answer.catch(() => undefined);
          throw error;
        }
        if (!result.delivered) {
          rejectWaiter(new Error(result.reason ?? "Question was not delivered"));
          await answer.catch(() => undefined);
          return errorResult(result.reason ?? "Question was not delivered", "DELIVERY_FAILED");
        }
        const reply = await answer;
        return { content: [{ type: "text" as const, text: reply.content.text }], details: { messageId: result.id, replyTo: reply.replyTo } satisfies ToolDetails };
      } catch (error) {
        return errorResult(error instanceof Error ? error.message : String(error), "SESSION_MESSAGE_FAILED");
      }
    },
  });
}
