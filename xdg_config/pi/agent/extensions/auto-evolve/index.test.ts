import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import { afterEach, describe, expect, test, vi } from "vitest";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import { registerAutoEvolveExtension } from "./index.ts";
import { EVOLVE_LOG_RELATIVE_PATH, scriptPath } from "./daemon.ts";

const REPO_ROOT = "/home/liu/tools/dotfiles";
const SKILL_DIR = fileURLToPath(new URL("./skill", import.meta.url));
const HEARTBEAT = `[${new Date().toISOString()}] === attempt 1: waiting 90s ===`;

const temporaryDirectories: string[] = [];

afterEach(() => {
    for (const directory of temporaryDirectories.splice(0)) {
        rmSync(directory, { recursive: true, force: true });
    }
});

function temporaryDirectory(): string {
    const directory = mkdtempSync(join(tmpdir(), "pi-auto-evolve-status-"));
    temporaryDirectories.push(directory);
    return directory;
}

interface CapturedTool {
    name: string;
    execute: (
        toolCallId: string,
        params: Record<string, unknown>,
        signal: unknown,
        onUpdate: unknown,
        ctx: unknown,
    ) => Promise<{ content: unknown; details: Record<string, unknown> }>;
}

function harness() {
    const tools: CapturedTool[] = [];
    const handlers = new Map<string, (event: unknown, ctx: unknown) => unknown>();
    const notifies: Array<{ message: string; type?: string }> = [];
    const ui = {
        notify: (message: string, type?: "info" | "warning" | "error") => {
            notifies.push({ message, type });
        },
    };
    const pi = {
        registerTool: (definition: CapturedTool) => {
            tools.push(definition);
        },
        on: (event: string, handler: (event: unknown, ctx: unknown) => unknown) => {
            handlers.set(event, handler);
        },
    } as unknown as ExtensionAPI;
    const ctx = { ui } as unknown as ExtensionContext;
    return { pi, tools, handlers, notifies, ctx };
}

function workerExec(options: { panesOutput?: string; noTmux?: boolean; pgrep?: string } = {}) {
    const { panesOutput = "", noTmux = false, pgrep = "" } = options;
    return vi.fn((cmd: string): string => {
        if (noTmux && cmd.startsWith("tmux ")) throw new Error("not in tmux");
        if (cmd.startsWith("tmux list-panes")) return panesOutput;
        if (cmd.startsWith("tmux display-message -p '#{session_name}'")) return "main";
        if (cmd.startsWith("tmux display-message -p '#{pane_id}'")) return "";
        if (cmd.startsWith("git -C")) return `${REPO_ROOT}\n`;
        if (cmd.startsWith("pgrep")) return pgrep;
        if (cmd.startsWith("kill -0")) return "";
        if (cmd.startsWith("kill -TERM")) return "";
        throw new Error(`unexpected cmd: ${cmd}`);
    });
}

const WORKER_PANES = [
    "%41\\t123\\tpi\\t/home/liu/tools/dotfiles",
    "%42\\t456\\tnode\\t/home/liu/tools/dotfiles/src",
    "%43\\t789\\tbash\\t/home/liu/tools/dotfiles",
].join("\n");

describe("conditional registration", () => {
    test("registers nothing and stays silent when no worker pane candidate exists", async () => {
        const { pi, tools, handlers, notifies, ctx } = harness();
        registerAutoEvolveExtension(pi, {
            exec: workerExec({ panesOutput: "" }),
            env: { TMUX_PANE: "%1" },
        });
        await handlers.get("session_start")!({ reason: "startup" }, ctx);

        expect(tools).toHaveLength(0);
        expect(notifies).toHaveLength(0);
        expect(await handlers.get("resources_discover")!({}, ctx)).toBeUndefined();
    });

    test("stays fully silent when not inside tmux even if panes exist", async () => {
        const { pi, tools, handlers, notifies, ctx } = harness();
        registerAutoEvolveExtension(pi, {
            exec: workerExec({ panesOutput: WORKER_PANES, noTmux: true }),
            env: {},
        });
        await handlers.get("session_start")!({ reason: "startup" }, ctx);

        expect(tools).toHaveLength(0);
        expect(notifies).toHaveLength(0);
        expect(await handlers.get("resources_discover")!({}, ctx)).toBeUndefined();
    });

    test("registers the three control tools and the skill when a worker pane is found", async () => {
        const { pi, tools, handlers, notifies, ctx } = harness();
        registerAutoEvolveExtension(pi, {
            exec: workerExec({ panesOutput: WORKER_PANES }),
            env: { TMUX_PANE: "%1" },
            spawn: vi.fn(() => ({ pid: 7777 })),
            touch: vi.fn(),
            readLogTail: vi.fn(() => HEARTBEAT),
        });
        await handlers.get("session_start")!({ reason: "startup" }, ctx);

        expect(tools.map((tool) => tool.name)).toEqual([
            "auto_evolve_status",
            "auto_evolve_start",
            "auto_evolve_stop",
        ]);
        expect(notifies).toHaveLength(1);
        expect(notifies[0].message).toContain("%41");
        expect(notifies[0].message).toContain("%42");
        expect(await handlers.get("resources_discover")!({}, ctx)).toEqual({
            skillPaths: [SKILL_DIR],
        });
    });

    test("does not re-register tools on a second session_start", async () => {
        const { pi, tools, handlers, ctx } = harness();
        registerAutoEvolveExtension(pi, {
            exec: workerExec({ panesOutput: WORKER_PANES }),
            env: { TMUX_PANE: "%1" },
        });
        await handlers.get("session_start")!({ reason: "startup" }, ctx);
        await handlers.get("session_start")!({ reason: "reload" }, ctx);
        expect(tools).toHaveLength(3);
    });
});

describe("auto_evolve_status", () => {
    async function registeredStatusTool(): Promise<ReturnType<typeof harness> & { status: CapturedTool }> {
        const state = harness();
        registerAutoEvolveExtension(state.pi, {
            exec: workerExec({ panesOutput: WORKER_PANES, pgrep: "4242" }),
            env: { TMUX_PANE: "%1" },
            readLogTail: vi.fn(() => HEARTBEAT),
        });
        await state.handlers.get("session_start")!({ reason: "startup" }, state.ctx);
        const status = state.tools.find((tool) => tool.name === "auto_evolve_status")!;
        return { ...state, status };
    }

    test("reports each candidate with its daemon status and the shared log path", async () => {
        const { status, ctx } = await registeredStatusTool();
        const result = await status.execute("c1", {}, undefined, undefined, ctx);

        const details = result.details as {
            logPath: string;
            panes: Array<{ paneId: string; daemon: { running: boolean } }>;
        };
        expect(details.logPath).toContain("auto-evolve.log");
        expect(details.panes).toHaveLength(2); // %41 and %42; %43 (bash) filtered out
        expect(details.panes[0].paneId).toBe("%41");
        expect(details.panes[0].daemon.running).toBe(true);
    });

    test("requests a bounded log tail snapshot per pane to keep context cheap", async () => {
        const state = harness();
        const readLogTail = vi.fn(() => HEARTBEAT);
        registerAutoEvolveExtension(state.pi, {
            exec: workerExec({ panesOutput: WORKER_PANES, pgrep: "4242" }),
            env: { TMUX_PANE: "%1" },
            readLogTail,
        });
        await state.handlers.get("session_start")!({ reason: "startup" }, state.ctx);
        const status = state.tools.find((tool) => tool.name === "auto_evolve_status")!;
        await status.execute("c1", {}, undefined, undefined, state.ctx);

        expect(readLogTail.mock.calls.length).toBeGreaterThan(0);
        for (const call of readLogTail.mock.calls) {
            expect(call[1]).toBe(2 * 1024);
        }
    });

    test("includes the evolveLog summary in details and content when EVOLVE_LOG exists", async () => {
        const state = harness();
        const root = temporaryDirectory();
        const evolveLogPath = join(root, "EVOLVE_LOG.md");
        writeFileSync(evolveLogPath, [
            "## 2026-08-24 Iteration 1 — first",
            "## 2026-08-25 Iteration 16 — previous",
            "## 2026-08-25 Iteration 17 — current",
        ].join("\n"));
        registerAutoEvolveExtension(state.pi, {
            exec: workerExec({ panesOutput: WORKER_PANES, pgrep: "4242" }),
            env: { TMUX_PANE: "%1" },
            readLogTail: vi.fn(() => HEARTBEAT),
            evolveLogPath,
        });
        await state.handlers.get("session_start")!({ reason: "startup" }, state.ctx);
        const status = state.tools.find((tool) => tool.name === "auto_evolve_status")!;
        const result = await status.execute("c1", {}, undefined, undefined, state.ctx);

        const details = result.details as {
            evolveLog: { iterations: number; lastIteration: string; path: string };
        };
        expect(details.evolveLog.iterations).toBe(3);
        expect(details.evolveLog.lastIteration).toContain("Iteration 17");
        expect(details.evolveLog.path).toBe(EVOLVE_LOG_RELATIVE_PATH);
        expect((result.content[0] as { text: string }).text).toContain(
            "Evolution: 3 iterations; latest: 2026-08-25 Iteration 17 — current",
        );
    });

    test("keeps status unchanged when no evolveLog summary is available", async () => {
        const state = harness();
        const root = temporaryDirectory();
        // Missing file: the fallback path keeps the pre-evolveLog status shape.
        const evolveLogPath = join(root, "missing", "EVOLVE_LOG.md");
        registerAutoEvolveExtension(state.pi, {
            exec: workerExec({ panesOutput: WORKER_PANES, pgrep: "4242" }),
            env: { TMUX_PANE: "%1" },
            readLogTail: vi.fn(() => HEARTBEAT),
            evolveLogPath,
        });
        await state.handlers.get("session_start")!({ reason: "startup" }, state.ctx);
        const status = state.tools.find((tool) => tool.name === "auto_evolve_status")!;
        const result = await status.execute("c1", {}, undefined, undefined, state.ctx);

        expect(result.details).not.toHaveProperty("evolveLog");
        expect((result.content[0] as { text: string }).text).not.toContain("Evolution:");
        expect((result.details as { logPath: string }).logPath).toContain("auto-evolve.log");
    });
});

describe("auto_evolve_start", () => {
    async function registeredStartTool(options: { pgrep?: string } = {}): Promise<ReturnType<typeof harness> & {
        start: CapturedTool;
        spawn: ReturnType<typeof vi.fn>;
        exec: ReturnType<typeof vi.fn>;
    }> {
        const state = harness();
        const spawn = vi.fn(() => ({ pid: 7777 }));
        const exec = workerExec({ panesOutput: WORKER_PANES, pgrep: options.pgrep ?? "" });
        registerAutoEvolveExtension(state.pi, {
            exec,
            env: { TMUX_PANE: "%1" },
            spawn,
            touch: vi.fn(),
            readLogTail: vi.fn(() => HEARTBEAT),
        });
        await state.handlers.get("session_start")!({ reason: "startup" }, state.ctx);
        const start = state.tools.find((tool) => tool.name === "auto_evolve_start")!;
        return { ...state, start, spawn, exec };
    }

    test("spawns the daemon for an explicit whitelisted pane", async () => {
        const { start, spawn, ctx } = await registeredStartTool();
        const result = await start.execute("c1", { pane: "%41" }, undefined, undefined, ctx);

        const details = result.details as { runId: string; paneId: string; pid: number; stopFile: string };
        expect(details.paneId).toBe("%41");
        expect(details.pid).toBe(7777);
        expect(details.stopFile).toContain("auto-evolve._41.stop");
        expect(details.runId).toMatch(/^\d+$/);
        expect(spawn).toHaveBeenCalledWith("bash", [scriptPath, "%41"], {
            env: expect.objectContaining({
                AUTO_EVOLVE_LOG: expect.stringContaining("auto-evolve.log"),
                AUTO_EVOLVE_STOP_FILE: expect.stringContaining("auto-evolve._41.stop"),
            }),
            detached: true,
            stdio: "ignore",
        });
    });

    test("defaults to the first candidate when pane is omitted", async () => {
        const { start, ctx } = await registeredStartTool();
        const result = await start.execute("c1", {}, undefined, undefined, ctx);
        expect((result.details as { paneId: string }).paneId).toBe("%41");
    });

    test("rejects a pane outside the probed whitelist", async () => {
        const { start, ctx } = await registeredStartTool();
        await expect(
            start.execute("c1", { pane: "%999" }, undefined, undefined, ctx),
        ).rejects.toThrow(/%999/);
    });

    test("reports already-running daemons instead of spawning twice", async () => {
        const { start, spawn, ctx } = await registeredStartTool({ pgrep: "9001\n" });
        const result = await start.execute("c1", { pane: "%41" }, undefined, undefined, ctx);
        expect(result.details).toEqual({ ok: false, reason: "already-running", paneId: "%41" });
        expect(spawn).not.toHaveBeenCalled();
    });
});

describe("auto_evolve_stop", () => {
    test("stops the daemon and reports the pane and actions taken", async () => {
        const state = harness();
        const touch = vi.fn();
        const exec = workerExec({ panesOutput: WORKER_PANES, pgrep: "9001\n" });
        registerAutoEvolveExtension(state.pi, {
            exec,
            env: { TMUX_PANE: "%1" },
            spawn: vi.fn(),
            touch,
            readLogTail: vi.fn(() => HEARTBEAT),
        });
        await state.handlers.get("session_start")!({ reason: "startup" }, state.ctx);
        const stop = state.tools.find((tool) => tool.name === "auto_evolve_stop")!;

        const result = await stop.execute("c1", { pane: "%41" }, undefined, undefined, state.ctx);
        const details = result.details as { paneId: string; stopped: boolean; actions: string[] };
        expect(details.paneId).toBe("%41");
        expect(details.stopped).toBe(true);
        expect(touch).toHaveBeenCalledWith(expect.stringContaining("auto-evolve._41.stop"));
        expect(exec.mock.calls.some(([cmd]) => cmd === "kill -TERM 9001")).toBe(true);
        expect(details.actions).toEqual([
            expect.stringContaining("touch:"),
            "kill -TERM 9001",
        ]);
    });

    test("defaults to the first candidate pane", async () => {
        const state = harness();
        registerAutoEvolveExtension(state.pi, {
            exec: workerExec({ panesOutput: WORKER_PANES, pgrep: "9001\n" }),
            env: { TMUX_PANE: "%1" },
            spawn: vi.fn(),
            touch: vi.fn(),
            readLogTail: vi.fn(() => HEARTBEAT),
        });
        await state.handlers.get("session_start")!({ reason: "startup" }, state.ctx);
        const stop = state.tools.find((tool) => tool.name === "auto_evolve_stop")!;
        const result = await stop.execute("c1", {}, undefined, undefined, state.ctx);
        expect((result.details as { paneId: string }).paneId).toBe("%41");
    });
});

describe("stale registration fail-closed", () => {
    test("tools that survive a candidate-less reload throw instead of acting", async () => {
        const state = harness();
        let panesOutput = WORKER_PANES;
        const exec = vi.fn((cmd: string): string => {
            if (cmd.startsWith("tmux list-panes")) return panesOutput;
            if (cmd.startsWith("tmux display-message -p '#{session_name}'")) return "main";
            if (cmd.startsWith("tmux display-message -p '#{pane_id}'")) return "";
            if (cmd.startsWith("git -C")) return `${REPO_ROOT}\n`;
            if (cmd.startsWith("pgrep")) return "9001\n";
            if (cmd.startsWith("kill -0")) return "";
            if (cmd.startsWith("kill -TERM")) return "";
            throw new Error(`unexpected cmd: ${cmd}`);
        });
        registerAutoEvolveExtension(state.pi, {
            exec,
            env: { TMUX_PANE: "%1" },
            spawn: vi.fn(),
            touch: vi.fn(),
            readLogTail: vi.fn(() => HEARTBEAT),
        });
        await state.handlers.get("session_start")!({ reason: "startup" }, state.ctx);
        expect(state.tools).toHaveLength(3);

        // A later reload finds no worker panes: tools stay registered but refuse.
        panesOutput = "";
        await state.handlers.get("session_start")!({ reason: "reload" }, state.ctx);
        expect(await state.handlers.get("resources_discover")!({}, state.ctx)).toBeUndefined();

        const start = state.tools.find((tool) => tool.name === "auto_evolve_start")!;
        await expect(
            start.execute("c1", {}, undefined, undefined, state.ctx),
        ).rejects.toThrow(/no worker pane candidates/);
    });
});