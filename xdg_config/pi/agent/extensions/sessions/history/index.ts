import { SessionManager } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { ErrorCodes, errorResult } from "../contracts.ts";
import { MAX_RESULTS, sessionsParameters } from "./contracts.ts";
import type { SessionEntry } from "@earendil-works/pi-coding-agent";
import type { SessionsInput } from "./contracts.ts";
import { buildHistoryResults } from "./search.ts";
import { compactJsonProjection, truncateProjectionField } from "../output.ts";

function modelString(value: string | undefined): string | undefined {
  return value === undefined ? undefined : truncateProjectionField(value, 1_000).value;
}

const MAX_ENTRY_TEXT = 2_000;

function entryText(entry: SessionEntry): string | undefined {
  if (entry.type === "message") {
    const content = (entry.message as { content?: unknown }).content;
    if (typeof content === "string") return content;
    if (Array.isArray(content)) {
      return content.filter((part): part is { type: "text"; text: string } => part?.type === "text")
        .map((part) => part.text).join("\\n");
    }
  }
  if (entry.type === "compaction" || entry.type === "branch_summary") return entry.summary;
  if (entry.type === "custom_message") return typeof entry.content === "string" ? entry.content : undefined;
  return undefined;
}

function projectEntry(entry: SessionEntry) {
  const text = entryText(entry);
  return {
    id: entry.id,
    parentId: entry.parentId,
    type: entry.type,
    timestamp: entry.timestamp,
    ...(text ? { text: truncateProjectionField(text, MAX_ENTRY_TEXT).value } : {}),
  };
}

export function registerSessionsTool(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "sessions",
    label: "Sessions",
    description: "Search local Pi session history or read bounded session entries.",
    parameters: sessionsParameters,
    async execute(_toolCallId, input: SessionsInput, _signal, _onUpdate, ctx?: ExtensionContext) {
      const limit = Math.min(input.limit ?? 10, MAX_RESULTS);
      const requestedCwd = input.cwd?.trim();
      const cwd = requestedCwd || (input.action === "get_entries" ? ctx?.cwd : undefined);

      if (input.action === "get_entries") {
        if ((input.sessionId?.trim() ? 1 : 0) + (input.path?.trim() ? 1 : 0) !== 1) {
          return errorResult("get_entries requires exactly one of sessionId or path", ErrorCodes.INVALID_ARGUMENT);
        }
        try {
          // Resolve through listAll first: this both enforces the cwd boundary and
          // prevents opening an arbitrary path supplied by the model.
          const sessions = await SessionManager.listAll();
          const target = sessions.find((session) =>
            (!cwd || session.cwd === cwd || session.cwd.startsWith(`${cwd}/`)) &&
            (input.sessionId?.trim() === session.id || input.path?.trim() === session.path),
          );
          if (!target) return errorResult("session not found within the allowed cwd", ErrorCodes.INVALID_ARGUMENT);

          const manager = SessionManager.open(target.path);
          const allEntries = manager.getEntries();
          const mode = input.mode ?? "summary";
          const selected = input.entryId
            ? manager.getBranch(input.entryId)
            : manager.buildContextEntries();
          if (input.entryId && !manager.getEntry(input.entryId)) {
            return errorResult("entry not found in session", ErrorCodes.INVALID_ARGUMENT);
          }
          const children = input.entryId ? manager.getChildren(input.entryId) : [];
          const entries = [...selected.slice(-limit), ...children.slice(0, input.around ?? 0)].slice(0, limit);
          const result = {
            kind: "history_detail" as const,
            sessionId: target.id,
            path: target.path,
            cwd: target.cwd,
            name: target.name,
            entryCount: allEntries.length,
            messageCount: target.messageCount,
            mode,
            ...(mode === "entries" ? { entries: entries.map(projectEntry) } : {
              summary: truncateProjectionField(target.firstMessage || target.allMessagesText, MAX_ENTRY_TEXT).value,
              latestEntry: allEntries.length ? projectEntry(allEntries[allEntries.length - 1]) : undefined,
            }),
          };
          return {
            content: [{ type: "text" as const, text: compactJsonProjection([result]) }],
            details: { result },
          };
        } catch (error) {
          return errorResult(`Unable to read session: ${error instanceof Error ? error.message : String(error)}`, ErrorCodes.INVALID_ARGUMENT);
        }
      }

      const query = input.query?.trim() ?? "";
      if (!query) return errorResult("query must not be empty", ErrorCodes.INVALID_QUERY);

      const sessions = await SessionManager.listAll();
      const results = buildHistoryResults(sessions as never, query, cwd, limit);
      const modelResults = results.map(({ sessionId, name, path, cwd: resultCwd, modified, snippet }) => ({
        sessionId: modelString(sessionId),
        name: modelString(name),
        path: modelString(path),
        cwd: modelString(resultCwd),
        modified,
        snippet,
      }));

      return {
        content: [
          {
            type: "text" as const,
            text: results.length
              ? compactJsonProjection(modelResults)
              : truncateProjectionField(`No sessions matched ${JSON.stringify(query)}.`, 16_000).value,
          },
        ],
        details: { query, results },
      };
    },
  });
}
