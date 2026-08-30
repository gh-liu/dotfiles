import { SessionManager } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@earendil-works/pi-coding-agent";
import { ErrorCodes, errorResult } from "./contracts.ts";
import { MAX_ENTRY_TEXT, MAX_RESULTS, sessionsReadParameters, sessionsSearchParameters } from "./contracts.ts";
import type { SessionsReadInput, SessionsSearchInput } from "./contracts.ts";
import { buildHistoryResults } from "./search.ts";
import { compactJsonProjection, truncateProjectionField } from "./output.ts";

function modelString(value: string | undefined): string | undefined {
  return value === undefined ? undefined : truncateProjectionField(value, 1_000).value;
}

function entryText(entry: SessionEntry): string | undefined {
  if (entry.type === "message") {
    const content = (entry.message as { content?: unknown }).content;
    if (typeof content === "string") return content;
    if (Array.isArray(content)) {
      return content.filter((part): part is { type: "text"; text: string } => part?.type === "text")
        .map((part) => part.text).join("\n");
    }
  }
  if (entry.type === "compaction" || entry.type === "branch_summary") return entry.summary;
  if (entry.type === "custom_message") return typeof entry.content === "string" ? entry.content : undefined;
  return undefined;
}

function projectEntry(entry: SessionEntry) {
  const text = entryText(entry);
  const role = entry.type === "message" ? (entry.message as { role?: string }).role : undefined;
  return {
    id: entry.id,
    parentId: entry.parentId,
    type: entry.type,
    timestamp: entry.timestamp,
    ...(role ? { role } : {}),
    ...(text ? { text: truncateProjectionField(text, MAX_ENTRY_TEXT).value } : {}),
  };
}

function registerSearch(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "sessions_search",
    label: "Sessions search",
    description: "Search local Pi session history.",
    parameters: sessionsSearchParameters,
    async execute(_toolCallId, input: SessionsSearchInput, _signal, _onUpdate, _ctx?: ExtensionContext) {
      const query = input.query?.trim() ?? "";
      if (!query) return errorResult("query must not be empty", ErrorCodes.INVALID_QUERY);
      const limit = Math.min(input.limit ?? 10, MAX_RESULTS);
      const cwd = input.cwd?.trim() || undefined;
      const sessions = await SessionManager.listAll();
      const results = buildHistoryResults(sessions as never, query, cwd, limit);
      const modelResults = results.map(({ sessionId, name, path, cwd: resultCwd, modified, snippet }) => ({
        sessionId: modelString(sessionId), name: modelString(name), path: modelString(path), cwd: modelString(resultCwd), modified, snippet,
      }));
      return {
        content: [{ type: "text" as const, text: results.length ? compactJsonProjection(modelResults) : truncateProjectionField(`No sessions matched ${JSON.stringify(query)}.`, 16_000).value }],
        details: { query, results },
      };
    },
  });
}

function registerRead(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "sessions_read",
    label: "Sessions read",
    description: "Read a bounded session summary or branch entries.",
    parameters: sessionsReadParameters,
    async execute(_toolCallId, input: SessionsReadInput, _signal, _onUpdate, ctx?: ExtensionContext) {
      const session = input.session?.trim();
      if (!session) return errorResult("session must not be empty", ErrorCodes.INVALID_ARGUMENT);
      const cwd = input.cwd?.trim() || ctx?.cwd;
      const entryLimit = Math.min(input.entryLimit ?? 10, MAX_RESULTS);
      const childLimit = Math.min(input.childLimit ?? 0, MAX_RESULTS);
      try {
        const sessions = await SessionManager.listAll();
        const target = sessions.find((candidate) =>
          (!cwd || candidate.cwd === cwd || candidate.cwd.startsWith(`${cwd}/`)) &&
          (candidate.id === session || candidate.path === session),
        );
        if (!target) return errorResult("session not found within the allowed cwd", ErrorCodes.INVALID_ARGUMENT);
        const manager = SessionManager.open(target.path);
        const allEntries = manager.getEntries();
        if (input.entryId && !manager.getEntry(input.entryId)) return errorResult("entry not found in session", ErrorCodes.INVALID_ARGUMENT);
        const result = {
          kind: "history_detail" as const, sessionId: target.id, path: target.path, cwd: target.cwd, name: target.name,
          entryCount: allEntries.length, messageCount: target.messageCount, mode: input.mode,
          ...(input.mode === "entries" ? {
            // Branch and child budgets are independent: children never consume branch entries.
            entries: (input.entryId ? manager.getBranch(input.entryId) : manager.buildContextEntries()).slice(-entryLimit).map(projectEntry),
            ...(input.entryId ? { childEntries: manager.getChildren(input.entryId).slice(0, childLimit).map(projectEntry) } : {}),
          } : {
            summary: truncateProjectionField(target.firstMessage || target.allMessagesText, MAX_ENTRY_TEXT).value,
            latestEntry: allEntries.length ? projectEntry(allEntries[allEntries.length - 1]) : undefined,
          }),
        };
        return { content: [{ type: "text" as const, text: compactJsonProjection([result]) }], details: { result } };
      } catch (error) {
        return errorResult(`Unable to read session: ${error instanceof Error ? error.message : String(error)}`, ErrorCodes.INVALID_ARGUMENT);
      }
    },
  });
}

/** Register the separate session-history search and reading tools. */
export default function sessionsExtension(pi: ExtensionAPI): void {
  registerSearch(pi);
  registerRead(pi);
}
