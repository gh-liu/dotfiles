import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { SessionManager } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const MAX_RESULTS = 20;
const MAX_SNIPPET_LENGTH = 240;

type FindSessionInput = {
  query: string;
  cwd?: string;
  limit?: number;
};

function snippet(text: string, query: string): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  const position = normalized.toLocaleLowerCase().indexOf(query.toLocaleLowerCase());
  if (position < 0) return normalized.slice(0, MAX_SNIPPET_LENGTH);

  const start = Math.max(0, position - 80);
  const end = Math.min(normalized.length, position + query.length + 160);
  return `${start > 0 ? "…" : ""}${normalized.slice(start, end)}${end < normalized.length ? "…" : ""}`;
}

export default function findSession(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "find_session",
    label: "Find Session",
    description:
      "Search local Pi session history and return matching sessions with context snippets.",
    parameters: Type.Object({
      query: Type.String({ description: "Text to search for in session history" }),
      cwd: Type.Optional(
        Type.String({
          description: "Only search sessions whose working directory starts with this path",
        }),
      ),
      limit: Type.Optional(
        Type.Integer({
          minimum: 1,
          maximum: MAX_RESULTS,
          description: "Maximum number of results",
        }),
      ),
    }),
    async execute(_toolCallId, input: FindSessionInput) {
      const query = input.query.trim();
      if (!query) throw new Error("query must not be empty");

      const limit = Math.min(input.limit ?? 10, MAX_RESULTS);
      const cwd = input.cwd?.trim();
      const sessions = await SessionManager.listAll();
      const matches = sessions
        .filter((session) => !cwd || session.cwd === cwd || session.cwd.startsWith(`${cwd}/`))
        .map((session) => ({
          session,
          position: session.allMessagesText.toLocaleLowerCase().indexOf(query.toLocaleLowerCase()),
        }))
        .filter((item) => item.position >= 0)
        .sort((a, b) => b.session.modified.getTime() - a.session.modified.getTime())
        .slice(0, limit);

      if (matches.length === 0) {
        return {
          content: [
            { type: "text" as const, text: `No sessions matched ${JSON.stringify(query)}.` },
          ],
          details: { query, results: [] },
        };
      }

      const results = matches.map(({ session }) => ({
        id: session.id,
        name: session.name,
        path: session.path,
        cwd: session.cwd,
        modified: session.modified.toISOString(),
        messageCount: session.messageCount,
        snippet: snippet(session.allMessagesText, query),
      }));
      const text = results
        .map((result, index) =>
          [
            `${index + 1}. ${result.name || result.id}`,
            `   session: ${result.id}`,
            `   cwd: ${result.cwd}`,
            `   modified: ${result.modified}`,
            `   ${result.snippet}`,
          ].join("\n"),
        )
        .join("\n\n");

      return { content: [{ type: "text" as const, text }], details: { query, results } };
    },
  });
}
