import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { randomUUID } from "node:crypto";
import { ErrorCodes, errorResult } from "../contracts.ts";
import { compactJsonProjection, truncateModelText, truncateProjectionField } from "../output.ts";
import type { ActiveSessionSendResult } from "./transport/index.ts";
import { ASK_TIMEOUT_MS, sessionMessageParameters } from "./contracts.ts";
import type { SessionMessageInput } from "./contracts.ts";
import type { SessionRuntime } from "./runtime.ts";

export function registerSessionMessageTool(pi: ExtensionAPI, runtime: SessionRuntime): void {
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
          let truncated = 0;
          const modelPending = pending.map((item) => {
            const message = truncateProjectionField(item.message);
            if (message.truncated) truncated += 1;
            return { ...item, message: message.value, messageTruncated: message.truncated || undefined };
          });
          return {
            content: [{ type: "text" as const, text: compactJsonProjection(modelPending, undefined, truncated) }],
            details: { pending },
          };
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
          content: [{ type: "text" as const, text: truncateModelText(reply.content.text) }],
          details: { messageId: result.id, replyTo: reply.replyTo, reply } as Record<string, unknown>,
        };
      } catch (error) {
        return errorResult(error instanceof Error ? error.message : String(error), ErrorCodes.SESSION_MESSAGE_FAILED);
      }
    },
  });
}
