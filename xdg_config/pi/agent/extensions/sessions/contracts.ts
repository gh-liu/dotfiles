import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";
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

export const MAX_RESULTS = 20;
export const MAX_SNIPPET_LENGTH = 240;
export const MAX_ENTRY_TEXT = 2_000;

export type SessionsSearchInput = {
  query: string;
  cwd?: string;
  limit?: number;
};

export type SessionsReadInput = {
  session: string;
  mode: "summary" | "entries";
  cwd?: string;
  entryId?: string;
  entryLimit?: number;
  childLimit?: number;
};

export const sessionsSearchParameters = Type.Object({
  query: Type.String({ minLength: 1, description: "Text to search for" }),
  cwd: Type.Optional(Type.String({ description: "Working-directory filter (defaults to all sessions)" })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_RESULTS })),
});

export const sessionsReadParameters = Type.Object({
  session: Type.String({ minLength: 1, description: "Exact session id or indexed session path" }),
  mode: StringEnum(["summary", "entries"] as const),
  cwd: Type.Optional(Type.String({ description: "Working-directory boundary (defaults to current cwd)" })),
  entryId: Type.Optional(Type.String({ description: "Entry id; selects its resolved branch" })),
  entryLimit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_RESULTS })),
  childLimit: Type.Optional(Type.Integer({ minimum: 0, maximum: MAX_RESULTS, description: "Direct children to include" })),
});
