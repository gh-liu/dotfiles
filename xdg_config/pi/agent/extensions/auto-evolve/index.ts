/**
 * Conditionally-registered auto-evolve control extension.
 *
 * On `session_start` the extension probes the current tmux session for a worker
 * pane that is already running Pi inside this repository. Only when at least
 * one candidate is found are the three control tools and the skill registered;
 * otherwise the extension stays completely silent: no tools, no notify, and no
 * side effects beyond a single debug log line.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { fileURLToPath } from "node:url";

import {
    detectCurrentPane,
    findWorkerCandidates,
    getCurrentSession,
    parsePanesOutput,
    PANES_FORMAT,
    type ExecFn,
    type PaneInfo,
} from "./probe.ts";
import {
    autoEvolveAgentDir,
    daemonStatus,
    defaultExec,
    defaultLogPath,
    getRepoRoot,
    readLogTail,
    shellQuote,
    spawnDaemon,
    startDaemon,
    stopDaemon,
    summarizeEvolveLog,
    touchFile,
    type ReadLogTailFn,
    type SpawnFn,
    type StopDaemonResult,
    type TouchFn,
} from "./daemon.ts";

const SKILL_DIR = fileURLToPath(new URL("./skill", import.meta.url));

/**
 * Bounded logTail budget for the status tool: the full daemon log lives at
 * logPath for deep reads, so the model-facing snapshot stays context-cheap.
 */
const STATUS_LOG_TAIL_MAX_BYTES = 2 * 1024;

export const TOOL_NAMES = [
    "auto_evolve_status",
    "auto_evolve_start",
    "auto_evolve_stop",
] as const;

export interface AutoEvolveOptions {
    agentDir?: string;
    env?: Record<string, string | undefined>;
    exec?: ExecFn;
    logPath?: string;
    readLogTail?: ReadLogTailFn;
    spawn?: SpawnFn;
    touch?: TouchFn;
    /** Agent evolve-namespace EVOLVE_LOG path; defaults to xdg_config/pi/agent/evolve/EVOLVE_LOG.md. */
    evolveLogPath?: string;
}

/** The current-pane tmux prompt probe, fully parameterized for tests. */
function probeWorkerCandidates(
    exec: ExecFn,
    env: Record<string, string | undefined>,
    repoRoot: string,
): PaneInfo[] {
    const currentPaneId = detectCurrentPane(env, exec);
    const session = getCurrentSession(exec);
    if (session === undefined) return [];
    const raw = exec(`tmux list-panes -t ${shellQuote(session)} -F '${PANES_FORMAT}'`);
    const panes = parsePanesOutput(raw);
    return findWorkerCandidates({ panes, currentPaneId, repoRoot });
}

export function registerAutoEvolveExtension(pi: ExtensionAPI, options: AutoEvolveOptions = {}): void {
    const exec = options.exec ?? defaultExec;
    const env = options.env ?? process.env;
    const agentDir = options.agentDir ?? autoEvolveAgentDir;
    const logPath = options.logPath ?? defaultLogPath(agentDir);
    // This file lives at .../agent/extensions/auto-evolve/index.ts, so "../../evolve/"
    // resolves into the agent/evolve namespace (the self-evolution directory the
    // shared log was relocated to from the agent root).
    const evolveLogPath = options.evolveLogPath
        ?? fileURLToPath(new URL("../../evolve/EVOLVE_LOG.md", import.meta.url));
    const readTail = options.readLogTail ?? readLogTail;
    const spawn = options.spawn ?? spawnDaemon;
    const touch = options.touch ?? touchFile;

    const registeredTools = new Set<string>();
    const probeState: { resolved: boolean; candidates: PaneInfo[] } = {
        resolved: false,
        candidates: [],
    };

    const currentCandidates = (): PaneInfo[] => probeState.candidates;

    /** Pane validation: defaults to the first candidate, rejects unknown ids. */
    const resolvePane = (pane: string | undefined, candidates: PaneInfo[]): PaneInfo => {
        if (candidates.length === 0) {
            throw new Error("auto-evolve: no worker pane candidates probed in this session");
        }
        const target = pane === undefined || pane === ""
            ? candidates[0]
            : candidates.find((candidate) => candidate.paneId === pane);
        if (!target) {
            throw new Error(
                `auto-evolve: unknown worker pane ${JSON.stringify(pane)}; allowed: `
                + candidates.map((candidate) => candidate.paneId).join(", "),
            );
        }
        return target;
    };

    const toolResult = <T>(details: T, text: string) => ({
        content: [{ type: "text" as const, text }],
        details,
    });

    const startParameters = Type.Object({
        pane: Type.Optional(Type.String({
            description: "Worker pane id (e.g. %41) from the probed whitelist; defaults to the first candidate.",
        })),
        target: Type.String({
            description: "The evolution target: the bounded work unit the daemon tells the worker Pi to keep improving. "
                + "The MAIN agent decides this explicitly on every start; there is no built-in default.",
        }),
    });
    const stopParameters = Type.Object({
        pane: Type.Optional(Type.String({
            description: "Worker pane id from the probed whitelist; defaults to the first candidate.",
        })),
    });
    type StartDetails =
        | { ok: false; reason: "already-running"; paneId: string }
        | { runId: string; paneId: string; pid: number; stopFile: string; logPath: string };

    const registerTools = (): void => {
        if (registeredTools.has(TOOL_NAMES[0])) return;

        pi.registerTool({
            name: "auto_evolve_status",
            label: "Auto-Evolve Status",
            description:
                "Report the worker panes probed in the current tmux session and whether each has an active "
                + "auto-evolve daemon (auto-evolve.sh), plus the shared daemon log path.",
            promptSnippet: "Report auto-evolve worker panes and daemon status.",
            promptGuidelines: [
                "Use auto_evolve_status before starting or stopping an auto-evolve daemon to confirm the target pane and current state.",
            ],
            parameters: Type.Object({}),
            async execute() {
                const candidates = currentCandidates();
                if (candidates.length === 0) {
                    throw new Error("auto-evolve: no worker pane candidates probed in this session");
                }
                const panes = candidates.map((candidate) => ({
                    paneId: candidate.paneId,
                    pid: candidate.pid,
                    command: candidate.command,
                    path: candidate.path,
                    daemon: daemonStatus({
                        paneId: candidate.paneId,
                        exec,
                        readLogTail: readTail,
                        agentDir,
                        logPath,
                        logTailMaxBytes: STATUS_LOG_TAIL_MAX_BYTES,
                    }),
                }));
                const evolveLog = summarizeEvolveLog(evolveLogPath);
                const details = evolveLog
                    ? { logPath, panes, evolveLog }
                    : { logPath, panes };
                const text = JSON.stringify(details, null, 2);
                const content = evolveLog
                    ? `Evolution: ${evolveLog.iterations} iterations; latest: ${evolveLog.lastIteration}\n${text}`
                    : text;
                return toolResult(details, content);
            },
        });

        pi.registerTool<typeof startParameters, StartDetails>({
            name: "auto_evolve_start",
            label: "Auto-Evolve Start",
            description:
                "Start the unattended auto-evolve daemon (auto-evolve.sh) for a probed worker pane. "
                + "The pane must be in the session-provided candidate whitelist; refuses when a daemon for that "
                + "pane is already running. The caller (main agent) must decide the `target` to evolve; there is "
                + "no hardcoded default target.",
            promptSnippet: "Start the auto-evolve daemon for a worker pane.",
            promptGuidelines: [
                "Only use pane ids reported by auto_evolve_status (or omit pane to use the first candidate).",
                "Decide the evolution `target` yourself: name the bounded work unit the daemon should tell the worker Pi to keep improving. There is no default.",
                "The daemon is unattended and keeps reloading the worker Pi; plan to stop it with auto_evolve_stop when the work is complete or out of scope.",
            ],
            parameters: startParameters,
            async execute(_toolCallId, params) {
                const target = resolvePane(params.pane, currentCandidates());
                const result = startDaemon({
                    paneId: target.paneId,
                    spawn,
                    exec,
                    agentDir,
                    logPath,
                    target: params.target,
                });
                if (!result.ok) {
                    return toolResult(
                        { ok: false, reason: result.reason, paneId: target.paneId },
                        JSON.stringify({ ok: false, reason: result.reason, paneId: target.paneId }, null, 2),
                    );
                }
                const runId = String(Date.now());
                const details = {
                    runId,
                    paneId: target.paneId,
                    target: params.target,
                    pid: result.pid,
                    stopFile: result.stopFile,
                    logPath: result.logPath,
                };
                return toolResult(details, JSON.stringify(details, null, 2));
            },
        });

        pi.registerTool<typeof stopParameters, StopDaemonResult>({
            name: "auto_evolve_stop",
            label: "Auto-Evolve Stop",
            description:
                "Stop the auto-evolve daemon for a probed worker pane by touching its stable stop file (graceful "
                + "exit signal) and sending SIGTERM. Returns the stopped pane and the actions taken.",
            promptSnippet: "Stop the auto-evolve daemon for a worker pane.",
            promptGuidelines: [
                "Stop the daemon when the evolution work is complete, blocked, or exceeds the requested bound; it will not stop itself otherwise.",
            ],
            parameters: stopParameters,
            async execute(_toolCallId, params) {
                const target = resolvePane(params.pane, currentCandidates());
                const result = stopDaemon({ paneId: target.paneId, exec, touch, agentDir });
                return toolResult(result, JSON.stringify(result, null, 2));
            },
        });

        // Keep the exported whitelist in sync with what was actually registered.
        for (const name of TOOL_NAMES) registeredTools.add(name);
    };

    pi.on("session_start", (_event, ctx) => {
        let candidates: PaneInfo[];
        try {
            const repoRoot = getRepoRoot(exec);
            candidates = probeWorkerCandidates(exec, env, repoRoot);
        } catch (error) {
            console.log(
                "[auto-evolve] probe failed; staying silent:",
                error instanceof Error ? error.message : String(error),
            );
            candidates = [];
        }
        probeState.resolved = true;
        probeState.candidates = candidates;
        if (candidates.length === 0) {
            console.log("[auto-evolve] no worker pane candidate in the current tmux session; tools and skill not registered");
            return;
        }
        ctx.ui.notify(
            `auto-evolve: control tools registered for worker pane(s) ${candidates.map((candidate) => candidate.paneId).join(", ")}`,
            "info",
        );
        registerTools();
    });

    pi.on("resources_discover", () => {
        if (probeState.resolved && probeState.candidates.length > 0) {
            return { skillPaths: [SKILL_DIR] };
        }
        return undefined;
    });
}

export default function autoEvolveExtension(pi: ExtensionAPI): void {
    registerAutoEvolveExtension(pi);
}