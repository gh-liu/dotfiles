import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import { Type } from "typebox";
import { defineTool, SessionManager, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

async function readParentSessionId(path: string, signal?: AbortSignal): Promise<string | undefined> {
  const input = createReadStream(path, { encoding: "utf8", signal });
  const lines = createInterface({ input, crlfDelay: Infinity });
  try {
    for await (const line of lines) {
      if (!line.trim()) continue;
      const header = JSON.parse(line);
      return header.type === "session" && typeof header.id === "string" ? header.id : undefined;
    }
  } catch {
    signal?.throwIfAborted();
    // Missing, unreadable or malformed parents must not hide otherwise valid sessions.
  } finally {
    lines.close();
    input.destroy();
  }
}

const readmePath = fileURLToPath(new URL("./README.md", import.meta.url));

export const listSessions = defineTool({
  name: "list_sessions",
  label: "List sessions",
  exposure: "direct",
  promptSnippet: "List saved Pi sessions by directory and title",
  description: `List saved Pi sessions (newest first) by directory and title. Use when finding or inspecting past Pi sessions instead of scanning session directories with bash; inspect a returned path with read. See ${readmePath} for field semantics and codemode usage.`,
  parameters: Type.Object({
    query: Type.Optional(Type.String({ description: "Case-insensitive title substring (trimmed; empty matches all)." })),
    currentDirectoryOnly: Type.Optional(Type.Boolean({ description: "Restrict to current cwd, excluding subdirs (default true)." })),
  }),
  outputSchema: Type.Array(Type.Object({
    id: Type.String(),
    title: Type.String(),
    path: Type.String(),
    parentSessionId: Type.Optional(Type.String()),
  })),
  async execute(_id, params, signal, _onUpdate, ctx) {
    const sessions = params.currentDirectoryOnly !== false
      ? await SessionManager.list(ctx.cwd, undefined, undefined, signal)
      : await SessionManager.listAll(undefined, signal);
    const query = params.query?.trim().toLowerCase() ?? "";
    const parentIds = new Map(sessions.map((session) => [session.path, session.id]));
    const result = [];
    for (const session of sessions) {
      const title = session.name || session.firstMessage;
      if (!title.toLowerCase().includes(query)) continue;
      const parentSessionId = session.parentSessionPath
        ? parentIds.get(session.parentSessionPath) ?? await readParentSessionId(session.parentSessionPath, signal)
        : undefined;
      if (parentSessionId) parentIds.set(session.parentSessionPath!, parentSessionId);
      result.push({
        id: session.id,
        title,
        path: session.path,
        ...(parentSessionId ? { parentSessionId } : {}),
      });
    }
    return {
      content: [{ type: "text", text: JSON.stringify(result) }],
      structuredContent: result,
      details: undefined,
    };
  },
});

export default function (pi: ExtensionAPI) {
  pi.registerTool(listSessions);
}
