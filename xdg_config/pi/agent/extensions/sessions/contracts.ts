import { truncateModelText } from "./output.ts";

export type ToolDetails = {
  error?: boolean;
  code?: string;
  [key: string]: unknown;
};

export const ErrorCodes = {
  INVALID_QUERY: "INVALID_QUERY",
  INVALID_ARGUMENT: "INVALID_ARGUMENT",
} as const;

export function errorResult(message: string, code: string) {
  return {
    content: [{ type: "text" as const, text: truncateModelText(message) }],
    details: { error: true, code } as ToolDetails,
  };
}
