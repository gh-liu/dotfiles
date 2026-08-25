/**
 * Pure, fully-injectable tmux probing primitives for the auto-evolve extension.
 *
 * Every function that touches the outside world (tmux, the environment) takes
 * its dependencies as parameters so unit tests can assert behavior without a
 * real tmux session.
 */

export interface PaneInfo {
    paneId: string;
    pid: string;
    command: string;
    path: string;
}

export type ExecFn = (cmd: string) => string;

/** Commands treated as "a Pi runtime" when deciding worker pane candidates. */
export const DEFAULT_PI_COMMANDS: readonly string[] = ["pi", "node", "nodejs", "bun"];

/**
 * tmux format string used to enumerate panes. tmux keeps the two-character
 * sequence `\t` (backslash + t) literally in format output, so `parsePanesOutput`
 * must normalize it before splitting.
 */
export const PANES_FORMAT = "#{pane_id}\\t#{pane_pid}\\t#{pane_current_command}\\t#{pane_current_path}";

/**
 * Parse `tmux list-panes -F` output.
 *
 * tmux preserves the literal two-character `\t` (backslash + t) in format
 * output, so raw lines must first be normalized to real tabs before splitting,
 * mirroring the `metadata="${metadata//\\t/$'\t'}"` trick in
 * auto-evolve.sh. Empty lines and rows with the wrong field count are
 * ignored.
 */
export function parsePanesOutput(raw: string): PaneInfo[] {
    const panes: PaneInfo[] = [];
    for (const rawLine of raw.split(/\r?\n/)) {
        const line = rawLine.trim();
        if (line === "") continue;
        // Normalize the literal "\t" (backslash + t) preserved by tmux.
        const fields = line.replace(/\\t/g, "\t").split("\t");
        if (fields.length !== 4) continue;
        const [paneId, pid, command, path] = fields;
        panes.push({
            paneId: paneId.trim(),
            pid: pid.trim(),
            command: command.trim(),
            path: path.trim(),
        });
    }
    return panes;
}

function basename(value: string): string {
    const index = value.lastIndexOf("/");
    return index >= 0 ? value.slice(index + 1) : value;
}

export interface FindWorkerCandidatesOptions {
    panes: PaneInfo[];
    currentPaneId: string | undefined;
    repoRoot: string;
    piCommands?: readonly string[];
}

/**
 * Keep panes that (1) are not the current pane, (2) run a supported Pi runtime
 * (basename match against piCommands, e.g. `/usr/bin/pi`), and (3) are inside
 * the repository.
 *
 * The repoRoot prefix must not bleed into a sibling directory:
 * `/home/liu/repo2` must NOT count as being under `/home/liu/repo`. A trailing
 * slash on repoRoot is tolerated; an exact repoRoot match is accepted as well.
 */
export function findWorkerCandidates(options: FindWorkerCandidatesOptions): PaneInfo[] {
    const { panes, currentPaneId, piCommands = DEFAULT_PI_COMMANDS } = options;
    const root = options.repoRoot.replace(/\/+$/, "");
    return panes.filter((pane) => {
        if (pane.paneId === currentPaneId) return false;
        if (!piCommands.includes(basename(pane.command))) return false;
        return pane.path === root || pane.path.startsWith(`${root}/`);
    });
}

/**
 * Resolve the current pane id: prefer `$TMUX_PANE` when present, otherwise ask
 * tmux. Returns undefined when no pane can be determined (e.g. not in tmux).
 */
export function detectCurrentPane(
    env: Record<string, string | undefined>,
    exec: ExecFn,
): string | undefined {
    const fromEnv = env.TMUX_PANE;
    if (fromEnv !== undefined && fromEnv.trim() !== "") return fromEnv.trim();
    try {
        const raw = exec("tmux display-message -p '#{pane_id}'").trim();
        return raw !== "" ? raw : undefined;
    } catch {
        return undefined;
    }
}

/**
 * Resolve the current tmux session name, used to scope `list-panes` to the
 * current session only (no cross-session scanning).
 */
export function getCurrentSession(exec: ExecFn): string | undefined {
    try {
        const raw = exec("tmux display-message -p '#{session_name}'").trim();
        return raw !== "" ? raw : undefined;
    } catch {
        return undefined;
    }
}