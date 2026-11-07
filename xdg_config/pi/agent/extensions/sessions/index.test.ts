import { mkdtemp, rename, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, expect, test, vi } from "vitest";
import { createReadTool, SessionManager, type ExtensionToolContext } from "@earendil-works/pi-coding-agent";
import { listSessions } from "./index.ts";

let root: string;

afterEach(async () => {
  vi.unstubAllEnvs();
  if (root) await rm(root, { recursive: true, force: true });
});

test("lists only session metadata across projects, with readable paths and codemode exposure", async () => {
  root = await mkdtemp(join(tmpdir(), "pi-list-sessions-"));
  vi.stubEnv("PI_CODING_AGENT_DIR", join(root, "agent"));
  const ctx = { cwd: join(root, "project-a") } as ExtensionToolContext;
  expect((await listSessions.execute("empty", {}, undefined, undefined, ctx)).structuredContent).toEqual([]);

  const named = SessionManager.create(join(root, "project-a"));
  named.appendMessage({ role: "user", content: "Original request", timestamp: Date.now() });
  named.appendSessionInfo("Renamed session");
  const unnamed = SessionManager.create(join(root, "project-b"));
  unnamed.appendMessage({ role: "user", content: "Unnamed request", timestamp: Date.now() });

  const result = await listSessions.execute("list", { currentDirectoryOnly: false }, undefined, undefined, ctx);
  expect(listSessions.exposure).toBe("codemode");
  expect(result.structuredContent).toHaveLength(2);
  expect(result.structuredContent).toEqual(expect.arrayContaining([
    { id: named.getSessionId(), title: "Renamed session", path: named.getSessionFile() },
    { id: unnamed.getSessionId(), title: "Unnamed request", path: unnamed.getSessionFile() },
  ]));
  const content = result.content[0];
  if (content.type !== "text") throw new Error("Expected text output");
  expect(JSON.parse(content.text)).toEqual(result.structuredContent);
  const read = await createReadTool(root).execute("read", { path: named.getSessionFile()! });
  expect(read.content).toEqual(expect.arrayContaining([
    expect.objectContaining({ type: "text", text: expect.stringContaining("Original request") }),
  ]));

  const list = async (params: { query?: string; currentDirectoryOnly?: boolean }) =>
    (await listSessions.execute("filter", params, undefined, undefined, ctx)).structuredContent;
  const namedResult = [{ id: named.getSessionId(), title: "Renamed session", path: named.getSessionFile() }];
  const unnamedResult = [{ id: unnamed.getSessionId(), title: "Unnamed request", path: unnamed.getSessionFile() }];
  expect(await list({ query: " RENAMED " })).toEqual(namedResult);
  expect(await list({ query: "request", currentDirectoryOnly: false })).toEqual(unnamedResult);
  expect(await list({ query: "Original" })).toEqual([]);
  expect(await list({})).toEqual(namedResult);
  expect(await list({ query: "   " })).toEqual(namedResult);
  expect(await list({ query: "request" })).toEqual([]);
  expect(await list({ currentDirectoryOnly: true })).toEqual(namedResult);
  expect(await list({ query: "session", currentDirectoryOnly: true })).toEqual(namedResult);
  expect(await list({ query: "request", currentDirectoryOnly: true })).toEqual([]);
  expect((await listSessions.execute("parent-directory", { currentDirectoryOnly: true },
    undefined, undefined, { cwd: root } as ExtensionToolContext)).structuredContent).toEqual([]);
});

test("resolves parent IDs outside filtered results from headers, omitting unavailable parents", async () => {
  root = await mkdtemp(join(tmpdir(), "pi-session-ancestry-"));
  vi.stubEnv("PI_CODING_AGENT_DIR", join(root, "agent"));
  const parent = SessionManager.create(join(root, "parent-project"));
  parent.appendMessage({ role: "user", content: "Parent task", timestamp: Date.now() });
  const parentPath = join(root, "renamed-parent.jsonl");
  await rename(parent.getSessionFile()!, parentPath);
  const child = SessionManager.create(join(root, "child-project"), undefined, { parentSession: parentPath });
  child.appendMessage({ role: "user", content: "Child task", timestamp: Date.now() });
  const ctx = { cwd: join(root, "child-project") } as ExtensionToolContext;
  const list = async () => (await listSessions.execute("ancestry", { query: "Child" }, undefined, undefined, ctx)).structuredContent;
  const metadata = { id: child.getSessionId(), title: "Child task", path: child.getSessionFile() };
  expect(await list()).toEqual([{ ...metadata, parentSessionId: parent.getSessionId() }]);
  await writeFile(parentPath, "invalid header\n");
  expect(await list()).toEqual([metadata]);
  await rm(parentPath);
  expect(await list()).toEqual([metadata]);
});
