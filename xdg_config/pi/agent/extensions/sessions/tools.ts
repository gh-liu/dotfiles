import { SessionManager } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { randomUUID } from "node:crypto";
import { ASK_TIMEOUT_MS, ErrorCodes, MAX_RESULTS, errorResult, sessionMessageParameters, sessionsParameters } from "./contracts.ts";
import type { SessionsInput, SessionMessageInput } from "./contracts.ts";
import { buildHistoryResults, formatActiveSession } from "./history.ts";
import type { SessionRuntime } from "./session-runtime.ts";
import type { ActiveSessionSendResult } from "./transport/index.ts";

export function registerSessionsTools(pi: ExtensionAPI, runtime: SessionRuntime): void {
  pi.registerTool({
    name: "sessions",
    label: "Sessions",
    description: "Search local Pi session history or list active Pi sessions reachable through local IPC.",
    parameters: sessionsParameters,
    async execute(_toolCallId, input: SessionsInput) {
      const limit = Math.min(input.limit ?? 10, MAX_RESULTS);
      const cwd = input.cwd?.trim();

      if (input.action === "list") {
        try {
          const active = await runtime.ensureClient();
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
          return errorResult(
            `Active sessions unavailable: ${error instanceof Error ? error.message : String(error)}`,
            ErrorCodes.INTERCOM_UNAVAILABLE,
          );
        }
      }

      const query = input.query?.trim() ?? "";
      if (!query) return errorResult("query must not be empty", ErrorCodes.INVALID_QUERY);

      const sessions = await SessionManager.listAll();
      const results = buildHistoryResults(sessions as never, query, cwd, limit);

      return {
        content: [
          {
            type: "text" as const,
            text: results.length ? JSON.stringify(results, null, 2) : `No sessions matched ${JSON.stringify(query)}.`,
          },
        ],
        details: { query, results },
      };
    },
  });

  pi.registerTool({
    name: "session_message",
    label: "Session Message",
    description: "Send a message to, ask, or reply to an active Pi session through local IPC.",
    parameters: sessionMessageParameters,
    async execute(_toolCallId, input: SessionMessageInput, signal) {
      try {
        const active = await runtime.ensureClient();

        if (input.action === "pending") {
          const pending = [...runtime.pendingInbound.values()].map(({ from, message }) => ({
            from: from.name ?? from.id,
            fromId: from.id,
            messageId: message.id,
            message: message.content.text,
          }));
          return { content: [{ type: "text" as const, text: JSON.stringify(pending, null, 2) }], details: { pending } };
        }

        if (input.action === "cancel") {
          if (!input.messageId) return errorResult("messageId is required", ErrorCodes.INVALID_ARGUMENT);
          const result = await active.cancel(input.messageId);
          return result.delivered
            ? {
                content: [{ type: "text" as const, text: `Cancellation requested for ${input.messageId}` }],
                details: result as unknown as Record<string, unknown>,
              }
            : errorResult(result.reason ?? "Cancellation was not delivered", ErrorCodes.DELIVERY_FAILED);
        }

        if (!input.message) return errorResult("message is required", ErrorCodes.INVALID_ARGUMENT);

        if (input.action === "reply") {
          const replyTo = input.replyTo ?? [...runtime.pendingInbound.keys()][0];
          if (!replyTo) return errorResult("replyTo is required when there is no pending inbound ask", ErrorCodes.NO_PENDING_ASK);
          const target = runtime.pendingInbound.get(replyTo);
          if (!target) return errorResult(`Unknown inbound message: ${replyTo}`, ErrorCodes.UNKNOWN_MESSAGE);
          const result = await active.send(target.from.id, { text: input.message, replyTo });
          if (!result.delivered) return errorResult(result.reason ?? "Reply was not delivered", ErrorCodes.DELIVERY_FAILED);
          runtime.pendingInbound.delete(replyTo);
          return {
            content: [{ type: "text" as const, text: `Reply sent to ${target.from.name ?? target.from.id}` }],
            details: result as unknown as Record<string, unknown>,
          };
        }

        if (!input.to) return errorResult("to is required", ErrorCodes.INVALID_ARGUMENT);

        const sessions = await active.listSessions();
        const target = sessions.find(
          (session) => session.id === input.to || session.name === input.to || session.id.startsWith(input.to!),
        );
        if (!target) return errorResult(`Active session not found: ${input.to}`, ErrorCodes.TARGET_NOT_FOUND);
        if (target.id === active.sessionId) return errorResult("Cannot message the current session", ErrorCodes.SELF_TARGET);

        if (input.action === "send") {
          const result = await active.send(target.id, { text: input.message });
          return result.delivered
            ? {
                content: [{ type: "text" as const, text: `Message sent to ${target.name ?? target.id}` }],
                details: result as unknown as Record<string, unknown>,
              }
            : errorResult(result.reason ?? "Message was not delivered", ErrorCodes.DELIVERY_FAILED);
        }

        // ask - upgraded to concurrent Map via AskRegistry; keep ASK_IN_PROGRESS code for compatibility but now supports concurrency.
        // To retain strict compatibility, uncomment the capacity check below. Currently we support concurrent asks.
        // if (runtime.askRegistry.size > 0) return errorResult("Already waiting for a reply", ErrorCodes.ASK_IN_PROGRESS);
        const messageId = randomUUID();
        const timeoutMs = input.timeoutMs ?? ASK_TIMEOUT_MS;

        const answer = runtime.askRegistry.create(messageId, timeoutMs, signal);
        // Prevent unhandled rejection while transport.send() is still pending.
        void answer.catch(() => undefined);
        if (signal.aborted) return await answer;

        let result: ActiveSessionSendResult;
        try {
          const send = active.send(target.id, { text: input.message, expectsReply: true, messageId });
          runtime.askRegistry.markSent(messageId);
          result = await send;
        } catch (error) {
          runtime.askRegistry.fail(messageId, error instanceof Error ? error : new Error(String(error)), false);
          await answer.catch(() => undefined);
          throw error;
        }

        if (!result.delivered) {
          runtime.askRegistry.fail(messageId, new Error(result.reason ?? "Question was not delivered"), false);
          await answer.catch(() => undefined);
          return errorResult(result.reason ?? "Question was not delivered", ErrorCodes.DELIVERY_FAILED);
        }

        const reply = await answer;
        return {
          content: [{ type: "text" as const, text: reply.content.text }],
          details: { messageId: result.id, replyTo: reply.replyTo } as Record<string, unknown>,
        };
      } catch (error) {
        return errorResult(error instanceof Error ? error.message : String(error), ErrorCodes.SESSION_MESSAGE_FAILED);
      }
    },
  });
}
