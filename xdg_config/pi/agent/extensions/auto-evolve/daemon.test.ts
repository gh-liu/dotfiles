import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { afterEach, describe, expect, test, vi } from "vitest";

import {
    daemonStatus,
    defaultLogPath,
    EVOLVE_LOG_RELATIVE_PATH,
    getRepoRoot,
    readLogTail,
    sanitizePaneId,
    scriptPath,
    startDaemon,
    stopDaemon,
    stopFilePathFor,
    summarizeEvolveLog,
} from "./daemon.ts";

const temporaryDirectories: string[] = [];

function temporaryDirectory(): string {
    const directory = mkdtempSync(join(tmpdir(), "pi-auto-evolve-daemon-"));
    temporaryDirectories.push(directory);
    return directory;
}

afterEach(() => {
    for (const directory of temporaryDirectories.splice(0)) {
        rmSync(directory, { recursive: true, force: true });
    }
});

function pgrepExec(pid: string | undefined, extra = ""): ReturnType<typeof vi.fn> {
    return vi.fn((cmd: string): string => {
        if (cmd.startsWith("pgrep")) return pid === undefined ? "" : pid;
        if (cmd.startsWith("kill -0") || cmd.startsWith("kill -TERM")) return "";
        throw new Error(`unexpected exec in test: ${cmd}; ${extra}`);
    });
}

describe("pane id helpers", () => {
    test("sanitizes tmux pane ids into shell-safe file tokens", () => {
        expect(sanitizePaneId("%41")).toBe("_41");
        expect(sanitizePaneId("foo-bar.baz_3")).toBe("foo-bar.baz_3");
    });

    test("derives the per-pane stable stop file", () => {
        expect(stopFilePathFor("/tmp/agent", "%41")).toBe("/tmp/agent/auto-evolve._41.stop");
    });
});

describe("getRepoRoot", () => {
    test("resolves the dotfiles toplevel through the injected exec", () => {
        const exec = vi.fn(() => "/home/liu/tools/dotfiles\n");
        expect(getRepoRoot(exec)).toBe("/home/liu/tools/dotfiles");
        const command = exec.mock.calls[0][0] as string;
        expect(command).toContain("git -C");
        expect(command).toContain("rev-parse --show-toplevel");
    });
});

describe("readLogTail", () => {
    test("reads the last maxBytes of a real log file", () => {
        const root = temporaryDirectory();
        const logPath = join(root, "auto-evolve.log");
        writeFileSync(logPath, "line 1\nline 2\nline 3\n");
        expect(readLogTail(logPath)).toBe("line 1\nline 2\nline 3\n");
    });
});

describe("summarizeEvolveLog", () => {
    test("counts iteration headings and bounds the last heading to one line", () => {
        const root = temporaryDirectory();
        const logPath = join(root, "EVOLVE_LOG.md");
        writeFileSync(logPath, [
            "# Agent self-evolution log",
            "",
            "## 2026-08-24 Iteration 1 — first round",
            "body",
            "## 2026-08-25 Iteration 16 — previous round",
            "## 2026-08-25 Iteration 17 —   spaced   heading",
            "",
        ].join("\n"));
        const summary = summarizeEvolveLog(logPath);
        expect(summary).toEqual({
            iterations: 3,
            lastIteration: "2026-08-25 Iteration 17 — spaced heading",
            path: EVOLVE_LOG_RELATIVE_PATH,
        });
    });

    test("returns undefined for a log without iteration headings or an empty file", () => {
        const root = temporaryDirectory();
        const noHeadings = join(root, "no-headings.md");
        writeFileSync(noHeadings, "# Plain log\nno iteration headings here\n");
        expect(summarizeEvolveLog(noHeadings)).toBeUndefined();
        const empty = join(root, "empty.md");
        writeFileSync(empty, "");
        expect(summarizeEvolveLog(empty)).toBeUndefined();
    });

    test("returns undefined for a missing or oversized log", () => {
        const root = temporaryDirectory();
        expect(summarizeEvolveLog(join(root, "missing.md"))).toBeUndefined();
        const large = join(root, "large.md");
        writeFileSync(large, "## Iteration 1\n" + "x".repeat(200));
        expect(summarizeEvolveLog(large, { maxBytes: 32 })).toBeUndefined();
    });
});

describe("startDaemon", () => {
    test("refuses when a daemon for the pane is already running", () => {
        const spawn = vi.fn();
        const exec = pgrepExec("9001\n");
        const result = startDaemon({ paneId: "%41", spawn, exec });
        expect(result).toEqual({ ok: false, reason: "already-running" });
        expect(spawn).not.toHaveBeenCalled();
    });

    test("spawns bash with the script, pane id, and the stable per-pane env", () => {
        const root = temporaryDirectory();
        const spawn = vi.fn(() => ({ pid: 4242 }));
        const exec = pgrepExec(undefined);
        const result = startDaemon({ paneId: "%41", spawn, exec, agentDir: root });
        expect(result).toEqual({
            ok: true,
            pid: 4242,
            stopFile: join(root, "auto-evolve._41.stop"),
            logPath: defaultLogPath(root),
        });
        expect(spawn).toHaveBeenCalledWith("bash", [scriptPath, "%41"], {
            env: expect.objectContaining({
                AUTO_EVOLVE_LOG: defaultLogPath(root),
                AUTO_EVOLVE_STOP_FILE: join(root, "auto-evolve._41.stop"),
            }),
            detached: true,
            stdio: "ignore",
        });
    });

    test("honors an explicit logPath override", () => {
        const root = temporaryDirectory();
        const spawn = vi.fn(() => ({ pid: 4242 }));
        const result = startDaemon({
            paneId: "%41",
            spawn,
            exec: pgrepExec(undefined),
            agentDir: root,
            logPath: "/custom/auto-evolve.log",
        });
        expect(result).toEqual({
            ok: true,
            pid: 4242,
            stopFile: join(root, "auto-evolve._41.stop"),
            logPath: "/custom/auto-evolve.log",
        });
        expect(spawn).toHaveBeenCalledWith("bash", [scriptPath, "%41"], {
            env: expect.objectContaining({ AUTO_EVOLVE_LOG: "/custom/auto-evolve.log" }),
            detached: true,
            stdio: "ignore",
        });
    });
});

describe("stopDaemon", () => {
    test("touches the stable stop file and TERMs the live daemon", () => {
        const root = temporaryDirectory();
        const touch = vi.fn();
        const exec = pgrepExec("9001\n");
        const result = stopDaemon({ paneId: "%41", exec, touch, agentDir: root });

        expect(result.stopped).toBe(true);
        expect(result.pid).toBe(9001);
        expect(touch).toHaveBeenCalledWith(join(root, "auto-evolve._41.stop"));
        expect(exec).toHaveBeenCalledWith("kill -0 9001");
        expect(exec).toHaveBeenCalledWith("kill -TERM 9001");
        expect(result.actions).toEqual([
            `touch:${join(root, "auto-evolve._41.stop")}`,
            "kill -TERM 9001",
        ]);
    });

    test("does nothing when no daemon is running", () => {
        const touch = vi.fn();
        const exec = pgrepExec(undefined);
        const result = stopDaemon({ paneId: "%41", exec, touch });
        expect(result).toEqual({ paneId: "%41", stopped: false, pid: undefined, actions: [] });
        expect(touch).not.toHaveBeenCalled();
        expect(exec).not.toHaveBeenCalledWith("kill -TERM 9001");
    });

    test("skips the TERM when the process died between pgrep and kill -0", () => {
        const touch = vi.fn();
        const exec = vi.fn((cmd: string): string => {
            if (cmd.startsWith("pgrep")) return "9001\n";
            if (cmd.startsWith("kill -0")) {
                throw new Error("process vanished");
            }
            if (cmd.startsWith("kill -TERM")) return "";
            throw new Error(`unexpected exec: ${cmd}`);
        });
        const result = stopDaemon({ paneId: "%41", exec, touch });
        expect(result.stopped).toBe(true);
        expect(touch).toHaveBeenCalled();
        expect(exec).not.toHaveBeenCalledWith("kill -TERM 9001");
        expect(result.actions).toContain("process-already-gone");
    });
});

describe("daemonStatus", () => {
    const heartbeat = (iso = new Date().toISOString()) => `[${iso}] === attempt 1: waiting 90s ===`;

    test("summarizes a running daemon with a fresh heartbeat as active", () => {
        const root = temporaryDirectory();
        const exec = pgrepExec("9001\n");
        const readLogTail = vi.fn(() => heartbeat());
        const status = daemonStatus({
            paneId: "%41",
            exec,
            readLogTail,
            agentDir: root,
            activeWindowMs: 60_000,
        });
        expect(status.running).toBe(true);
        expect(status.pid).toBe(9001);
        expect(status.active).toBe(true);
        expect(status.lastHeartbeat).toContain("waiting 90s");
        expect(status.logPath).toBe(defaultLogPath(root));
        expect(status.stopFile).toBe(join(root, "auto-evolve._41.stop"));
    });

    test("reports a stale heartbeat as inactive", () => {
        const exec = pgrepExec("9001\n");
        const readLogTail = vi.fn(() => heartbeat("2020-01-01T00:00:00.000Z"));
        const status = daemonStatus({ paneId: "%41", exec, readLogTail, activeWindowMs: 60_000 });
        expect(status.running).toBe(true);
        expect(status.active).toBe(false);
    });

    test("reports not running when pgrep finds no daemon", () => {
        const root = temporaryDirectory();
        const exec = pgrepExec(undefined);
        const readLogTail = vi.fn(() => heartbeat());
        const status = daemonStatus({ paneId: "%41", exec, readLogTail, agentDir: root });
        expect(status.running).toBe(false);
        expect(status.pid).toBeUndefined();
        expect(status.active).toBe(false);
    });

    test("tolerates a missing log file", () => {
        const root = temporaryDirectory();
        const exec = pgrepExec(undefined);
        const readLogTail = vi.fn(() => {
            throw new Error("ENOENT");
        });
        const status = daemonStatus({ paneId: "%41", exec, readLogTail, agentDir: root });
        expect(status.logTail).toBeUndefined();
        expect(status.lastHeartbeat).toBeUndefined();
        expect(status.running).toBe(false);
    });

    test("caps the exposed log tail to the requested byte budget", () => {
        const root = temporaryDirectory();
        const exec = pgrepExec("9001\n");
        const readLogTail = vi.fn((_path: string, maxBytes = 8 * 1024) => "x".repeat(200).slice(-maxBytes));
        const status = daemonStatus({
            paneId: "%41",
            exec,
            readLogTail,
            agentDir: root,
            logTailMaxBytes: 16,
            activeWindowMs: 60_000,
        });
        expect(readLogTail).toHaveBeenCalledWith(defaultLogPath(root), 16);
        expect(status.logTail).toBe("x".repeat(16));
        expect(status.running).toBe(true);
    });
});