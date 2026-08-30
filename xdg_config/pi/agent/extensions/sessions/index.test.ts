import { SessionManager } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI, ExtensionContext, ToolDefinition } from "@earendil-works/pi-coding-agent";
import { afterEach, describe, expect, test, vi } from "vitest";
import sessionsExtension from "./index.ts";

function harness() {
  const tools = new Map<string, ToolDefinition>();
  const pi = {
    registerTool(tool: ToolDefinition) { tools.set(tool.name, tool); },
  } as unknown as ExtensionAPI;
  sessionsExtension(pi);
  return { tools };
}

function context(): ExtensionContext {
  return { cwd: "/work", mode: "rpc", hasUI: false, model: undefined, scopedModels: [], signal: undefined,
    sessionManager: {} as never, isIdle: () => true } as unknown as ExtensionContext;
}

afterEach(() => vi.restoreAllMocks());

describe("sessions history extension", () => {
  test("registers only history actions and does not construct IPC", () => {
    const { tools } = harness();
    expect([...tools.keys()]).toEqual(["sessions"]);
    expect(tools.get("session_message")).toBeUndefined();
  });

  test("search history works independently of IPC", async () => {
    vi.spyOn(SessionManager, "listAll").mockResolvedValue([]);
    const { tools } = harness();
    const result = await tools.get("sessions")!.execute("call", { action: "search_history", query: "old message" }, undefined, undefined, context());
    expect(SessionManager.listAll).toHaveBeenCalledOnce();
    expect((result.content[0] as { text: string }).text).toContain("No sessions matched");
  });

  test("reads a bounded branch-aware history excerpt", async () => {
    vi.spyOn(SessionManager, "listAll").mockResolvedValue([{
      id: "history-1", name: "old", path: "/safe/session.jsonl", cwd: "/work", modified: new Date(1),
      messageCount: 2, firstMessage: "first", allMessagesText: "first second",
    }] as never);
    const entries = [
      { id: "root", parentId: null, type: "message", timestamp: "2020-01-01T00:00:00Z", message: { role: "user", content: "first" } },
      { id: "reply", parentId: "root", type: "message", timestamp: "2020-01-01T00:00:01Z", message: { role: "assistant", content: "second" } },
    ];
    vi.spyOn(SessionManager, "open").mockReturnValue({
      getEntries: () => entries, getBranch: () => entries, getEntry: (id: string) => entries.find((entry) => entry.id === id),
      getChildren: (id: string) => entries.filter((entry) => entry.parentId === id), buildContextEntries: () => entries,
    } as never);
    const { tools } = harness();
    const result = await tools.get("sessions")!.execute("read", {
      action: "get_entries", sessionId: "history-1", mode: "entries", entryId: "reply", limit: 1,
    }, undefined, undefined, context());
    expect(result.details).toMatchObject({ result: { sessionId: "history-1", entries: [{ id: "reply", text: "second" }] } });
  });

});
