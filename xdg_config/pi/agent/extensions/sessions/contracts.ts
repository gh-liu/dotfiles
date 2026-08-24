import { truncateModelText } from "./output.ts";

/**
 * Cross-capability shared contracts only.
 * Capability-specific input types / parameter schemas live in history/contracts.ts
 * and messaging/contracts.ts so the two capabilities never depend on each other.
 */

export type ActiveSession = {
  id: string;
  name?: string;
  cwd: string;
  model: string;
  pid: number;
  startedAt: number;
  lastActivity: number;
  status?: string;
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
    content: [{ type: "text" as const, text: truncateModelText(message) }],
    details: { error: true, code } as ToolDetails,
  };
}
