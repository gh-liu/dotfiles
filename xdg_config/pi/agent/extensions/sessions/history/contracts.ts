import { StringEnum } from "@earendil-works/pi-ai";
import { Type } from "typebox";

export const MAX_RESULTS = 20;
export const MAX_SNIPPET_LENGTH = 240;

export type SessionsInput = {
  action: "search_history" | "get_entries";
  query?: string;
  cwd?: string;
  limit?: number;
  sessionId?: string;
  path?: string;
  entryId?: string;
  around?: number;
  mode?: "summary" | "entries";
};

export const sessionsParameters = Type.Object({
  action: StringEnum(["search_history", "get_entries"] as const),
  query: Type.Optional(Type.String({ description: "Text to search for (search_history only)" })),
  cwd: Type.Optional(Type.String({ description: "Working-directory filter" })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_RESULTS })),
  sessionId: Type.Optional(Type.String({ description: "Session id (get_entries only)" })),
  path: Type.Optional(Type.String({ description: "Session path (get_entries only)" })),
  entryId: Type.Optional(Type.String({ description: "Entry id; selects its resolved branch (get_entries only)" })),
  around: Type.Optional(Type.Integer({ minimum: 0, maximum: 10, description: "Number of direct child entries to include" })),
  mode: Type.Optional(StringEnum(["summary", "entries"] as const)),
});
