import { SessionManager } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { ErrorCodes, errorResult } from "../contracts.ts";
import type { ActiveSession } from "../contracts.ts";
import { MAX_RESULTS, sessionsParameters } from "./contracts.ts";
import type { SessionsInput } from "./contracts.ts";
import { buildHistoryResults, formatActiveSession } from "./search.ts";
import { compactJsonProjection, truncateProjectionField } from "../output.ts";

function modelString(value: string | undefined): string | undefined {
  return value === undefined ? undefined : truncateProjectionField(value, 1_000).value;
}

/**
 * Injected IPC dependency for the "list" action, so this capability never
 * imports SessionRuntime or any internals of the session_message capability.
 */
export type ActiveSessionsProvider = () => Promise<{ sessions: ActiveSession[]; currentId: string | null }>;

export function registerSessionsTool(pi: ExtensionAPI, listActiveSessions: ActiveSessionsProvider): void {
  pi.registerTool({
    name: "sessions",
    label: "Sessions",
    description: "Search local Pi session history or list active Pi sessions reachable through local IPC.",
    parameters: sessionsParameters,
    async execute(_toolCallId, input: SessionsInput) {
      const limit = Math.min(input.limit ?? 10, MAX_RESULTS);
      const cwd = input.cwd?.trim();

      if (input.action === "list") {
        try {
          const active = await listActiveSessions();
          const peers = active.sessions
            .filter((session) => !cwd || session.cwd === cwd || session.cwd.startsWith(`${cwd}/`))
            .slice(0, limit)
            .map((session) => formatActiveSession(session, active.currentId));
          const modelPeers = peers.map(({ sessionId, name, cwd, status, self }) => ({
            sessionId: modelString(sessionId), name: modelString(name), cwd: modelString(cwd), status, self,
          }));
          return {
            content: [{ type: "text" as const, text: peers.length ? compactJsonProjection(modelPeers) : "No active sessions found." }],
            details: { results: peers },
          };
        } catch (error) {
          return errorResult(
            `Active sessions unavailable: ${error instanceof Error ? error.message : String(error)}`,
            ErrorCodes.INTERCOM_UNAVAILABLE,
          );
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
