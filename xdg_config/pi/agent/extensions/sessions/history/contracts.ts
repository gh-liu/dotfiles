import { Type } from "typebox";

export const MAX_RESULTS = 20;
export const MAX_SNIPPET_LENGTH = 240;

export type SessionsInput = {
  action: "search_history" | "list";
  query?: string;
  cwd?: string;
  limit?: number;
};

export const sessionsParameters = Type.Object({
  action: Type.Union([Type.Literal("search_history"), Type.Literal("list")]),
  query: Type.Optional(Type.String({ description: "Text to search for (search_history only)" })),
  cwd: Type.Optional(Type.String({ description: "Working-directory filter" })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: MAX_RESULTS })),
});
