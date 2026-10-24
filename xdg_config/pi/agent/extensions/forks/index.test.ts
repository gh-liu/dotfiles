import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, expect, test, vi } from "vitest";
import type { ExtensionAPI, ExtensionContext, SessionStartEvent } from "@earendil-works/pi-coding-agent";
import forks from "./index.ts";

let root: string;
afterEach(async () => {
  vi.unstubAllEnvs();
  if (root) await rm(root, { recursive: true, force: true });
});

async function setup(failure?: "start" | "restore-move" | "move" | "shell-starting", label = "Review", sessionName?: string, existingLabels: string[] = []) {
  root = await mkdtemp(join(tmpdir(), "pi-forks-"));
  const previous = join(root, "old session.jsonl");
  await writeFile(previous, "fixture");
  vi.stubEnv("HERDR_ENV", "1");
  vi.stubEnv("HERDR_PANE_ID", "p1");
  vi.stubEnv("HERDR_TAB_ID", "stale-tab");
  const panes = new Map([
    ["p1", { pane_id: "p1", tab_id: "original", session: "new session.jsonl", ready: true }],
  ]);
  const tabs = [{ tab_id: "original", label, number: 3 }, ...existingLabels.map((label, index) => ({ tab_id: `sibling-${index}`, label, number: index + 4 }))];
  let focused = "original";
  let shellStarting = failure === "shell-starting";
  let waitingTabs: string[] = [];
  const warnings: string[] = [];
  let handler: (event: SessionStartEvent, ctx: ExtensionContext) => Promise<void>;
  const pi = {
    on: (_: string, fn: typeof handler) => { handler = fn; },
    exec: async (_: string, args: string[]) => {
      const option = (name: string) => args[args.indexOf(name) + 1];
      let result;
      if (args[0] === "pane" && args[1] === "current") result = { pane: { ...panes.get("p1"), workspace_id: "workspace" } };
      else if (args[0] === "tab" && args[1] === "list") result = { tabs };
      else if ((args[0] === "tab" && args[1] === "create") || (args[0] === "pane" && args[1] === "split")) {
        const tab = args[0] === "tab" ? "preparing" : panes.get(option("--pane"))!.tab_id;
        const pane = { pane_id: "p2", tab_id: tab, session: "", ready: false };
        panes.set("p2", pane);
        result = args[0] === "tab" ? { root_pane: pane } : { pane };
      } else if (args[0] === "agent" && args[1] === "start") {
        waitingTabs = [...panes.values()].map(pane => pane.tab_id);
        if (shellStarting) {
          shellStarting = false;
          return { code: 1, stderr: JSON.stringify({ error: { code: "agent_pane_busy" } }), stdout: "", killed: false };
        }
        const pane = panes.get(option("--pane"))!;
        pane.session = option("--session");
        // A failed readiness check may still have launched the process.
        if (failure === "start") return { code: 1, stderr: "readiness timeout", stdout: "", killed: false };
        pane.ready = true;
        result = { agent: pane };
      } else if (args[0] === "pane" && args[1] === "move") {
        if ((failure === "move" && args[2] === "p1") || (failure === "restore-move" && args[2] === "p2")) {
          result = { move_result: { changed: false, reason: "rejected" } };
        } else {
          panes.get(args[2])!.tab_id = args.includes("--new-tab") ? "new-tab" : option("--tab");
          if (args.includes("--new-tab")) tabs.push({ tab_id: "new-tab", label: args.includes("--label") ? option("--label") : "4", number: 4 });
          if (args.includes("--focus")) focused = panes.get(args[2])!.tab_id;
          result = { move_result: { changed: true } };
        }
      } else throw new Error(`Unexpected command: ${args.join(" ")}`);
      return { code: 0, stderr: "", stdout: JSON.stringify({ result }), killed: false };
    },
  } as unknown as ExtensionAPI;
  forks(pi);
  const ctx = { mode: "tui", cwd: root, sessionManager: { getSessionName: () => sessionName }, ui: { notify: (message: string) => warnings.push(message) } } as unknown as ExtensionContext;
  return {
    previous, panes, tabs, warnings, focus: () => focused, waitingTabs: () => waitingTabs,
    start: (reason: SessionStartEvent["reason"] = "fork", mode = "tui") =>
      handler({ type: "session_start", reason, previousSessionFile: previous }, { ...ctx, mode } as ExtensionContext),
  };
}

test.each([undefined, "shell-starting"] as const)("fork preserves the original tab and focuses the new session (shell: %s)", async (failure) => {
  const app = await setup(failure);
  await app.start();
  expect([...app.panes.values()]).toEqual([
    { pane_id: "p1", tab_id: "new-tab", session: "new session.jsonl", ready: true },
    { pane_id: "p2", tab_id: "original", session: app.previous, ready: true },
  ]);
  expect(app.focus()).toBe("new-tab");
  expect(app.waitingTabs()).toEqual(["original", "preparing"]);
  expect(app.tabs.find(tab => tab.tab_id === "original")?.label).toBe("Review");
  expect(app.tabs.find(tab => tab.tab_id === "new-tab")?.label).toBe("Review · fork");
  expect(app.warnings).toEqual([]);
});

test.each([
  ["3", "Session α", [], "Session α · fork"],
  ["3", undefined, [], "Pi · fork"],
  ["5", "Session α", [], "Session α · fork"],
  ["Review", "Session α", ["Review · fork", "Review · fork 2", "Review · fork 4"], "Review · fork 3"],
] as const)("names a fork from tab %s and session %s without collisions", async (label, sessionName, existingLabels, expected) => {
  const app = await setup(undefined, label, sessionName, [...existingLabels]);
  await app.start();
  expect(app.tabs.find(tab => tab.tab_id === "original")?.label).toBe(label);
  expect(app.tabs.find(tab => tab.tab_id === "new-tab")?.label).toBe(expected);
  expect(app.warnings).toEqual([]);
});

test.each(["start", "restore-move", "move"] as const)("%s failure preserves both sessions and warns", async (failure) => {
  const app = await setup(failure);
  await app.start();
  expect(app.panes.get("p1")?.session).toBe("new session.jsonl");
  expect(app.panes.get("p1")?.tab_id).toBe("original");
  expect(app.panes.get("p2")?.session).toBe(app.previous);
  expect(app.panes.get("p2")?.tab_id).toBe(failure === "move" ? "original" : "preparing");
  expect(app.warnings).toHaveLength(1);
  expect(app.warnings[0]).toContain("left intact");
});

test("startup, resume, reload and non-TUI sessions leave layout alone", async () => {
  const app = await setup();
  for (const reason of ["startup", "resume", "reload", "new"] as const) await app.start(reason);
  await app.start("fork", "rpc");
  await app.start("fork", "print");
  expect(app.panes.size).toBe(1);
  expect(app.panes.get("p1")?.tab_id).toBe("original");
  expect(app.warnings).toEqual([]);
});

test.each([undefined, "", "0", "true"])("does not register events when HERDR_ENV is %s", (value) => {
  vi.stubEnv("HERDR_ENV", value);
  const on = vi.fn();
  forks({ on } as unknown as ExtensionAPI);
  expect(on).not.toHaveBeenCalled();
});
