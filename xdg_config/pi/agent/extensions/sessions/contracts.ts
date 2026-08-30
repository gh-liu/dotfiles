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
  query: Type.String({ minLength: 1, description: "Text to find in session messages; search first to obtain a sessionId or path for sessions_read" }),
  cwd: Type.Optional(Type.String({ description: "Restrict matches to this working directory and its descendants; defaults to all sessions" })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_RESULTS, description: "Maximum number of bounded session metadata and snippet results" })),
});

export const sessionsReadParameters = Type.Object({
  session: Type.String({ minLength: 1, description: "Exact sessionId or indexed session path returned by sessions_search" }),
  mode: StringEnum(["summary", "entries"] as const, { description: "summary: bounded metadata/overview and latest entry; entries: branch-aware conversation entries" }),
  cwd: Type.Optional(Type.String({ description: "Security boundary: allow only this directory or descendants; defaults to the current cwd" })),
  entryId: Type.Optional(Type.String({ description: "Entry id whose resolved branch to read; also enables direct child entries in entries mode" })),
  entryLimit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_RESULTS, description: "Maximum branch entries to return; output remains bounded" })),
  childLimit: Type.Optional(Type.Integer({ minimum: 0, maximum: MAX_RESULTS, description: "Maximum direct child entries to return independently of entryLimit" })),
});
