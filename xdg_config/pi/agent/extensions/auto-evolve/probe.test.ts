import { describe, expect, test, vi } from "vitest";

import {
    detectCurrentPane,
    findWorkerCandidates,
    getCurrentSession,
    parsePanesOutput,
    type PaneInfo,
} from "./probe.ts";

describe("parsePanesOutput", () => {
    test("normalizes the literal \\t sequences tmux preserves before splitting", () => {
        const raw = [
            "%41\\t123\\tpi\\t/home/liu/tools/dotfiles",
            "%42\\t456\\tnodejs\\t/home/liu/tools/dotfiles/src",
            "",
        ].join("\n");
        expect(parsePanesOutput(raw)).toEqual([
            { paneId: "%41", pid: "123", command: "pi", path: "/home/liu/tools/dotfiles" },
            { paneId: "%42", pid: "456", command: "nodejs", path: "/home/liu/tools/dotfiles/src" },
        ]);
    });

    test("ignores blank lines and rows with the wrong field count", () => {
        const raw = [
            "",
            "   ",
            "%41\\t123\\tpi", // 3 fields: dropped
            "%42\\t456\\tnode\\t/home/liu/tools/dotfiles\\textra", // 5 fields: dropped
            "%43\\t789\\tbun\\t/home/liu/tools/dotfiles", // valid
        ].join("\n");
        expect(parsePanesOutput(raw)).toEqual([
            { paneId: "%43", pid: "789", command: "bun", path: "/home/liu/tools/dotfiles" },
        ]);
    });
});

describe("findWorkerCandidates", () => {
    const panes: PaneInfo[] = [
        { paneId: "%1", pid: "1", command: "pi", path: "/home/liu/repo" },
        { paneId: "%2", pid: "2", command: "/usr/bin/pi", path: "/home/liu/repo/src" },
        { paneId: "%3", pid: "3", command: "bash", path: "/home/liu/repo" },
        { paneId: "%4", pid: "4", command: "node", path: "/home/liu/repo/src" },
        { paneId: "%5", pid: "5", command: "bun", path: "/home/liu" },
        { paneId: "%6", pid: "6", command: "pi", path: "/other/repo" },
        { paneId: "%7", pid: "7", command: "nodejs", path: "/home/liu/repo/tools" },
    ];

    test("excludes the current pane and non-Pi commands", () => {
        const candidates = findWorkerCandidates({ panes, currentPaneId: "%4", repoRoot: "/home/liu/repo" });
        expect(candidates.map((candidate) => candidate.paneId)).toEqual(["%1", "%2", "%7"]);
    });

    test("matches command basenames and respects the repoRoot prefix boundary", () => {
        const candidates = findWorkerCandidates({ panes, currentPaneId: "%1", repoRoot: "/home/liu/repo" });
        // %1 (current pane) excluded; %2 matches /usr/bin/pi under repo/src;
        // %3 (bash) excluded; %4 (node under repo/src) matches; %5 (bun) at
        // /home/liu is NOT under /home/liu/repo; %6 outside the repo; %7 matches.
        expect(candidates.map((candidate) => candidate.paneId)).toEqual(["%2", "%4", "%7"]);
    });

    test("repoRoot exactly equals a pane path and subpaths are both accepted", () => {
        const panes2: PaneInfo[] = [
            { paneId: "%8", pid: "8", command: "pi", path: "/home/liu/repo" },
            { paneId: "%9", pid: "9", command: "pi", path: "/home/liu/repo2" },
        ];
        const candidates = findWorkerCandidates({ panes: panes2, currentPaneId: undefined, repoRoot: "/home/liu/repo" });
        expect(candidates.map((candidate) => candidate.paneId)).toEqual(["%8"]);
    });

    test("tolerates a trailing slash on repoRoot", () => {
        const panes2: PaneInfo[] = [
            { paneId: "%10", pid: "10", command: "pi", path: "/home/liu/repo" },
            { paneId: "%11", pid: "11", command: "pi", path: "/home/liu/repo/src" },
            { paneId: "%12", pid: "12", command: "pi", path: "/home/liu/repo2" },
        ];
        const candidates = findWorkerCandidates({
            panes: panes2,
            currentPaneId: undefined,
            repoRoot: "/home/liu/repo/",
        });
        expect(candidates.map((candidate) => candidate.paneId)).toEqual(["%10", "%11"]);
    });
});

describe("detectCurrentPane", () => {
    test("prefers $TMUX_PANE when present", () => {
        const exec = vi.fn(() => "%99");
        expect(detectCurrentPane({ TMUX_PANE: "%41" }, exec)).toBe("%41");
        expect(exec).not.toHaveBeenCalled();
    });

    test("falls back to tmux display-message when the env value is empty", () => {
        const exec = vi.fn(() => "%41\n");
        expect(detectCurrentPane({ TMUX_PANE: "" }, exec)).toBe("%41");
        expect(exec).toHaveBeenCalledWith("tmux display-message -p '#{pane_id}'");
    });

    test("returns undefined when tmux is unavailable", () => {
        const exec = vi.fn(() => {
            throw new Error("tmux: command not found");
        });
        expect(detectCurrentPane({}, exec)).toBeUndefined();
    });
});

describe("getCurrentSession", () => {
    test("returns the current session name", () => {
        const exec = vi.fn(() => "main\n");
        expect(getCurrentSession(exec)).toBe("main");
        expect(exec).toHaveBeenCalledWith("tmux display-message -p '#{session_name}'");
    });

    test("returns undefined when tmux is unavailable", () => {
        const exec = vi.fn(() => {
            throw new Error("no tmux");
        });
        expect(getCurrentSession(exec)).toBeUndefined();
    });
});