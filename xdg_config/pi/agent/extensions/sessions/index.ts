import { createReadStream } from "node:fs";
import { createInterface } from "node:readline";
import { Type } from "@earendil-works/pi-ai";
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

export const listSessions = defineTool({
  name: "list_sessions",
  label: "List sessions",
  description: "List saved Pi sessions for the current working directory by default, newest modified first. Set currentDirectoryOnly to false to search all projects. Returns id, title (session name or first user message), absolute JSONL file path, and parentSessionId when resolvable. Parent IDs describe session ancestry, not message branches or execution ownership; parents may be outside the filtered results. Use read on path to inspect a session; large files may require offset/limit. Raw JSONL includes branches, not just the current conversation path.",
  exposure: "codemode",
  parameters: Type.Object({
    query: Type.Optional(Type.String({ description: "Case-insensitive substring of the title. Surrounding whitespace is ignored; empty matches all titles." })),
    currentDirectoryOnly: Type.Optional(Type.Boolean({ description: "Only sessions for the current working directory, not subdirectories. Default: true. Set false for all projects." })),
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
