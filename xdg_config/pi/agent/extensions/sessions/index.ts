import { Type } from "@earendil-works/pi-ai";
import { defineTool, SessionManager, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

export const listSessions = defineTool({
  name: "list_sessions",
  label: "List sessions",
  description: "List saved Pi sessions for the current working directory by default, newest modified first. Set currentDirectoryOnly to false to search all projects. Returns id, title (session name or first user message), and absolute JSONL file path. Use read on path to inspect a session; large files may require offset/limit. Raw JSONL includes branches, not just the current conversation path.",
  exposure: "codemode",
  parameters: Type.Object({
    query: Type.Optional(Type.String({ description: "Case-insensitive substring of the title. Surrounding whitespace is ignored; empty matches all titles." })),
    currentDirectoryOnly: Type.Optional(Type.Boolean({ description: "Only sessions for the current working directory, not subdirectories. Default: true. Set false for all projects." })),
  }),
  outputSchema: Type.Array(Type.Object({
    id: Type.String(),
    title: Type.String(),
    path: Type.String(),
  })),
  async execute(_id, params, signal, _onUpdate, ctx) {
    const sessions = params.currentDirectoryOnly !== false
      ? await SessionManager.list(ctx.cwd, undefined, undefined, signal)
      : await SessionManager.listAll(undefined, signal);
    const query = params.query?.trim().toLowerCase() ?? "";
    const result = sessions.map((session) => ({
      id: session.id,
      title: session.name || session.firstMessage,
      path: session.path,
    })).filter((session) => session.title.toLowerCase().includes(query));
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
