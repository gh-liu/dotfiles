import type { ActiveSession } from "./transport/index.ts";
import { MAX_SNIPPET_LENGTH } from "./contracts.ts";

export function snippet(text: string, query: string): string {
  const normalized = text.replace(/\s+/g, " ").trim();
  const position = normalized.toLocaleLowerCase().indexOf(query.toLocaleLowerCase());
  if (position < 0) return normalized.slice(0, MAX_SNIPPET_LENGTH);

  const start = Math.max(0, position - 80);
  const end = Math.min(normalized.length, position + query.length + 160);
  return `${start > 0 ? "…" : ""}${normalized.slice(start, end)}${end < normalized.length ? "…" : ""}`;
}

export function formatActiveSession(session: ActiveSession, currentId: string | null) {
  return {
    kind: "active" as const,
    instanceId: session.id,
    sessionId: session.id,
    name: session.name,
    cwd: session.cwd,
    model: session.model,
    status: session.status ?? "unknown",
    lastActivity: new Date(session.lastActivity).toISOString(),
    self: session.id === currentId,
  };
}

export function filterByCwd<T extends { cwd: string }>(items: T[], cwd?: string): T[] {
  if (!cwd) return items;
  return items.filter((item) => item.cwd === cwd || item.cwd.startsWith(`${cwd}/`));
}

export type HistorySession = {
  id: string;
  name?: string;
  path: string;
  cwd: string;
  modified: Date;
  messageCount: number;
  allMessagesText: string;
};

export function buildHistoryResults(
  sessions: HistorySession[],
  query: string,
  cwd: string | undefined,
  limit: number,
) {
  const normalizedQuery = query.toLocaleLowerCase();
  return sessions
    .filter((session) => !cwd || session.cwd === cwd || session.cwd.startsWith(`${cwd}/`))
    .map((session) => ({
      session,
      position: session.allMessagesText.toLocaleLowerCase().indexOf(normalizedQuery),
    }))
    .filter((item) => item.position >= 0)
    .sort((a, b) => b.session.modified.getTime() - a.session.modified.getTime())
    .slice(0, limit)
    .map(({ session }) => ({
      kind: "history" as const,
      sessionId: session.id,
      name: session.name,
      path: session.path,
      cwd: session.cwd,
      modified: session.modified.toISOString(),
      messageCount: session.messageCount,
      snippet: snippet(session.allMessagesText, query),
    }));
}
