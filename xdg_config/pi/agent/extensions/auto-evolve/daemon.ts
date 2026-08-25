/**
 * Lifecycle helpers for the auto-evolve daemon (`auto-evolve.sh`).
 *
 * All side-effect capabilities (spawn, exec, touch, readLogTail) are injected
 * as parameters so unit tests can assert behavior without starting a real
 * daemon, touching a real file, or signaling a real process.
 */

import { execSync, spawn as nodeSpawn } from "node:child_process";
import { closeSync, fstatSync, openSync, readSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export type ExecFn = (cmd: string) => string;
export type SpawnFn = (
    command: string,
    args: readonly string[],
    options: { env: Record<string, string | undefined>; detached: boolean; stdio: "ignore" },
) => { pid?: number };
export type TouchFn = (path: string) => void;
export type ReadLogTailFn = (path: string, maxBytes?: number) => string;

/** Absolute path to the existing daemon script, which we never modify. */
export const scriptPath = fileURLToPath(new URL("./auto-evolve.sh", import.meta.url));
/** .../agent/extensions (parent of the auto-evolve extension directory). */
export const extensionsDir = dirname(dirname(scriptPath));
/** .../agent — the AGENT_DIR the daemon script itself derives from its location. */
export const autoEvolveAgentDir = dirname(extensionsDir);

/** Heartbeats newer than this window count as an "active" daemon. */
export const DEFAULT_DAEMON_ACTIVE_MS = 5 * 60 * 1_000;

/** Default byte budget for the logTail snapshot in daemonStatus. */
export const DEFAULT_DAEMON_LOG_TAIL_BYTES = 8 * 1024;

export function shellQuote(value: string): string {
    return `'${value.replace(/'/g, "'\\''")}'`;
}

/** The dotfiles repo root daemons may evolve: git toplevel of the extensions dir. */
export function getRepoRoot(exec: ExecFn = defaultExec): string {
    return exec(`git -C ${shellQuote(extensionsDir)} rev-parse --show-toplevel`).trim();
}

/** Turn `%41` into a shell- and file-name-safe token (`_41`). */
export function sanitizePaneId(paneId: string): string {
    return paneId.replace(/[^A-Za-z0-9_.-]/g, "_");
}

/** Stable per-pane stop signal path used by both start and stop. */
export function stopFilePathFor(agentDir: string, paneId: string): string {
    return join(agentDir, `auto-evolve.${sanitizePaneId(paneId)}.stop`);
}

export function defaultLogPath(agentDir: string): string {
    return join(agentDir, "auto-evolve.log");
}

export function defaultExec(cmd: string): string {
    return execSync(cmd, { encoding: "utf8" });
}

export const spawnDaemon: SpawnFn = (command, args, options) => nodeSpawn(command, args, options);

export function touchFile(path: string): void {
    const fd = openSync(path, "a");
    closeSync(fd);
}

/** Read the last ~8KB (and up to maxLines lines) of a log file. */
export function readLogTail(path: string, maxBytes = 8 * 1024, maxLines = 60): string {
    const fd = openSync(path, "r");
    try {
        const size = fstatSync(fd).size;
        if (size === 0) return "";
        const bytesToRead = Math.min(size, maxBytes);
        const buffer = Buffer.alloc(bytesToRead);
        readSync(fd, buffer, 0, bytesToRead, size - bytesToRead);
        return buffer.toString("utf8").split(/\r?\n/).slice(-maxLines).join("\n");
    } finally {
        closeSync(fd);
    }
}

/** Evolution log inside the agent/evolve namespace, relative to the repo root. */
export const EVOLVE_LOG_RELATIVE_PATH = "xdg_config/pi/agent/evolve/EVOLVE_LOG.md";

/** Read the entire EVOLVE_LOG file; throws when the file exceeds maxBytes. */
export function readEvolveLog(path: string, maxBytes = 1_048_576): string {
    const fd = openSync(path, "r");
    try {
        const size = fstatSync(fd).size;
        if (size > maxBytes) {
            throw new Error(`Evolve log exceeds ${maxBytes} bytes`);
        }
        const buffer = Buffer.alloc(size);
        let offset = 0;
        while (offset < size) {
            const bytesRead = readSync(fd, buffer, offset, size - offset, offset);
            if (bytesRead === 0) break;
            offset += bytesRead;
        }
        return buffer.subarray(0, offset).toString("utf8");
    } finally {
        closeSync(fd);
    }
}

/**
 * Summarize the agent-level EVOLVE_LOG: count `## ... Iteration N` headings and
 * bound the last heading to one 80-character line (mirrors the subagent
 * boundText contract without a cross-extension dependency). Returns undefined
 * when the log is unreadable, oversized, or has no iteration headings.
 */
export function summarizeEvolveLog(
    path: string,
    opts?: { maxBytes?: number },
): { iterations: number; lastIteration: string; path: string } | undefined {
    try {
        const log = readEvolveLog(path, opts?.maxBytes);
        const headings = [...log.matchAll(/^##\s+.*\bIteration\s+\d+\b.*$/gim)]
            .map((match) => match[0].replace(/^##\s+/, ""));
        const lastHeading = headings.at(-1);
        if (!lastHeading) return undefined;
        const lastIteration = lastHeading.replace(/\s+/g, " ").trim();
        return {
            iterations: headings.length,
            lastIteration: lastIteration.length <= 80 ? lastIteration : "[truncated]",
            path: EVOLVE_LOG_RELATIVE_PATH,
        };
    } catch {
        return undefined;
    }
}

/** First numeric pid matched by `pgrep -f "auto-evolve.sh <paneId>"`, if any. */
function pgrepDaemonPid(exec: ExecFn, paneId: string): number | undefined {
    try {
        const output = exec(`pgrep -f "auto-evolve.sh ${paneId}"`).trim();
        const match = /^(\d+)/m.exec(output);
        return match ? Number(match[1]) : undefined;
    } catch {
        return undefined;
    }
}

export interface StartDaemonOptions {
    paneId: string;
    spawn: SpawnFn;
    exec: ExecFn;
    agentDir?: string;
    logPath?: string;
    /** Evolution target decided by the main agent; forwarded to the daemon via AUTO_EVOLVE_TARGET. */
    target?: string;
}

export type StartDaemonResult =
    | { ok: true; pid: number; stopFile: string; logPath: string }
    | { ok: false; reason: "already-running" };

/**
 * Refuse duplicates for the same pane, then spawn the daemon detached with the
 * per-pane stable stop file and agent log wired through the environment.
 */
export function startDaemon(options: StartDaemonOptions): StartDaemonResult {
    const { paneId, spawn, exec } = options;
    const agentDir = options.agentDir ?? autoEvolveAgentDir;
    const logPath = options.logPath ?? defaultLogPath(agentDir);
    const stopFile = stopFilePathFor(agentDir, paneId);
    if (pgrepDaemonPid(exec, paneId) !== undefined) {
        return { ok: false, reason: "already-running" };
    }
    const env: Record<string, string | undefined> = {
        ...process.env,
        AUTO_EVOLVE_LOG: logPath,
        AUTO_EVOLVE_STOP_FILE: stopFile,
    };
    if (options.target !== undefined) {
        env.AUTO_EVOLVE_TARGET = options.target;
    }
    const child = spawn("bash", [scriptPath, paneId], {
        env,
        detached: true,
        stdio: "ignore",
    });
    if (child.pid === undefined) {
        throw new Error("auto-evolve: spawned daemon did not expose a pid");
    }
    return { ok: true, pid: child.pid, stopFile, logPath };
}

export interface StopDaemonOptions {
    paneId: string;
    exec: ExecFn;
    touch: TouchFn;
    agentDir?: string;
}

export interface StopDaemonResult {
    paneId: string;
    stopped: boolean;
    pid: number | undefined;
    actions: string[];
}

/**
 * Touch the stable stop file (the daemon's graceful exit signal) and, if the
 * process is still alive, send SIGTERM. Only acts when a daemon is running.
 */
export function stopDaemon(options: StopDaemonOptions): StopDaemonResult {
    const { paneId, exec, touch } = options;
    const agentDir = options.agentDir ?? autoEvolveAgentDir;
    const pid = pgrepDaemonPid(exec, paneId);
    if (pid === undefined) {
        return { paneId, stopped: false, pid: undefined, actions: [] };
    }
    const actions: string[] = [];
    const stopFile = stopFilePathFor(agentDir, paneId);
    touch(stopFile);
    actions.push(`touch:${stopFile}`);
    let alive = true;
    try {
        exec(`kill -0 ${pid}`);
    } catch {
        alive = false;
    }
    if (alive) {
        exec(`kill -TERM ${pid}`);
        actions.push(`kill -TERM ${pid}`);
    } else {
        actions.push("process-already-gone");
    }
    return { paneId, stopped: true, pid, actions };
}

export interface DaemonStatusOptions {
    paneId: string;
    exec: ExecFn;
    readLogTail: ReadLogTailFn;
    agentDir?: string;
    logPath?: string;
    activeWindowMs?: number;
    /** Byte budget for the logTail snapshot exposed to consumers (default 8KB). */
    logTailMaxBytes?: number;
}

export interface DaemonStatusResult {
    paneId: string;
    running: boolean;
    pid: number | undefined;
    logPath: string;
    stopFile: string;
    lastHeartbeat: string | undefined;
    active: boolean;
    logTail: string | undefined;
}

/** Structured daemon digest: alive? plus the most recent log heartbeat line. */
export function daemonStatus(options: DaemonStatusOptions): DaemonStatusResult {
    const { paneId, exec, readLogTail, logTailMaxBytes } = options;
    const agentDir = options.agentDir ?? autoEvolveAgentDir;
    const logPath = options.logPath ?? defaultLogPath(agentDir);
    const pid = pgrepDaemonPid(exec, paneId);
    let logTail: string | undefined;
    try {
        logTail = readLogTail(logPath, logTailMaxBytes ?? DEFAULT_DAEMON_LOG_TAIL_BYTES);
    } catch {
        logTail = undefined;
    }
    const lastLine = logTail
        ? logTail.split(/\r?\n/).filter((line) => line.trim() !== "").at(-1)
        : undefined;
    const timestampMatch = lastLine?.match(
        /\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}))\]/,
    );
    const lastTimestamp = timestampMatch ? Date.parse(timestampMatch[1]) : NaN;
    // "active" means the daemon is alive AND its heartbeat is fresh.
    const active = pid !== undefined
        && Number.isFinite(lastTimestamp)
        && Date.now() - lastTimestamp <= (options.activeWindowMs ?? DEFAULT_DAEMON_ACTIVE_MS);
    return {
        paneId,
        running: pid !== undefined,
        pid,
        logPath,
        stopFile: stopFilePathFor(agentDir, paneId),
        lastHeartbeat: lastLine,
        active,
        logTail,
    };
}