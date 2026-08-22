import { Type } from "typebox";

export const ASK_TIMEOUT_MS = 10 * 60 * 1000;

export type SessionMessageInput = {
  action: "send" | "ask" | "reply" | "pending" | "cancel";
  to?: string;
  message?: string;
  replyTo?: string;
  messageId?: string;
  timeoutMs?: number;
};

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
