import { Type } from "typebox";

export const MAX_RESULTS = 20;
export const MAX_SNIPPET_LENGTH = 240;
export const ASK_TIMEOUT_MS = 10 * 60 * 1000;

export type SessionsInput = {
  action: "search_history" | "list";
  query?: string;
  cwd?: string;
  limit?: number;
};

export type SessionMessageInput = {
  action: "send" | "ask" | "reply" | "pending" | "cancel";
  to?: string;
  message?: string;
  replyTo?: string;
  messageId?: string;
  timeoutMs?: number;
};

export type ToolDetails = {
  error?: boolean;
  code?: string;
  [key: string]: unknown;
};

export const ErrorCodes = {
  INVALID_QUERY: "INVALID_QUERY",
  INTERCOM_UNAVAILABLE: "INTERCOM_UNAVAILABLE",
  INVALID_ARGUMENT: "INVALID_ARGUMENT",
  NO_PENDING_ASK: "NO_PENDING_ASK",
  UNKNOWN_MESSAGE: "UNKNOWN_MESSAGE",
  DELIVERY_FAILED: "DELIVERY_FAILED",
  ASK_IN_PROGRESS: "ASK_IN_PROGRESS",
  TARGET_NOT_FOUND: "TARGET_NOT_FOUND",
  SELF_TARGET: "SELF_TARGET",
  SESSION_MESSAGE_FAILED: "SESSION_MESSAGE_FAILED",
} as const;

export function errorResult(message: string, code: string) {
  return {
    content: [{ type: "text" as const, text: message }],
    details: { error: true, code } as ToolDetails,
  };
}

export const sessionsParameters = Type.Object({
  action: Type.Union([Type.Literal("search_history"), Type.Literal("list")]),
  query: Type.Optional(Type.String({ description: "Text to search for (search_history only)" })),
  cwd: Type.Optional(Type.String({ description: "Working-directory filter" })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_RESULTS })),
});

export const sessionMessageParameters = Type.Object({
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
});
