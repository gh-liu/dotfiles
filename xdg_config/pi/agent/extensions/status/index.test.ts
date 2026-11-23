import { watch } from "node:fs";
import { homedir } from "node:os";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import { SettingsManager, type ExtensionAPI, type ExtensionContext, type SessionEntry, type Theme } from "@earendil-works/pi-coding-agent";
import type { Usage } from "@earendil-works/pi-ai";
import { stripTerminalSequences, visibleWidth } from "@earendil-works/pi-tui";

// Keep footer tests independent of user settings and filesystem watcher timing.
vi.mock("node:fs", async (importOriginal) => ({
  ...await importOriginal<typeof import("node:fs")>(),
  watch: vi.fn(() => ({ close: vi.fn(), on: vi.fn() })),
}));
import status, { formatDirectory } from "./index.ts";

type Handler = (event: any, context: ExtensionContext) => void | Promise<void>;

const disposers: Array<() => void> = [];

afterEach(() => {
  for (const dispose of disposers.splice(0)) dispose();
  vi.restoreAllMocks();
  vi.unstubAllEnvs();
});

function setup(options: {
  idle?: boolean;
  oauth?: boolean;
  provider?: string;
  model?: { provider: string; id: string; contextWindow: number } | undefined;
  subscriptionAuth?: boolean;
  thinking?: "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
  cwd?: string;
  branch?: string | null;
  sessionName?: string;
  entries?: SessionEntry[];
  contextUsage?: { percent: number | null; contextWindow: number; tokens: number | null };
  borderColor?: (text: string) => string;
} = {}) {
  let autoCompact = true;
  vi.spyOn(SettingsManager, "create").mockImplementation(() => ({
    getCompactionEnabled: () => autoCompact,
  }) as SettingsManager);
  let entries = options.entries ?? [];
  let contextUsage = options.contextUsage ?? { percent: 12.5, contextWindow: 100_000, tokens: 12_500 };
  const handlers = new Map<string, Handler>();
  let footerFactory: ((tui: any, theme: Theme, footerData: any) => any) | undefined;
  let editorFactory: ((tui: any, theme: any, keybindings: any) => any) | undefined;
  let idle = options.idle ?? true;
  let sessionName = options.sessionName;
  const setWorkingVisible = vi.fn();
  const model = "model" in options
    ? options.model
    : {
      provider: options.provider ?? "example",
      id: "model",
      contextWindow: 100_000,
    };
  const sessionManager = {
    getEntries: () => entries,
  };
  const context = {
    cwd: options.cwd ?? process.cwd(),
    mode: "tui",
    model,
    sessionManager,
    modelRegistry: {
      getProvider: () => ({ auth: { oauth: options.subscriptionAuth ? { isSubscription: true } : undefined } }),
      isUsingOAuth: () => options.oauth ?? false,
    },
    getContextUsage: () => contextUsage,
    isIdle: () => idle,
    isProjectTrusted: () => true,
    ui: {
      setFooter: (factory: typeof footerFactory) => { footerFactory = factory; },
      setEditorComponent: (factory: typeof editorFactory) => { editorFactory = factory ?? undefined; },
      setWorkingVisible,
    },
  } as unknown as ExtensionContext;
  const pi = {
    getThinkingLevel: () => options.thinking,
    getSessionName: () => sessionName,
    on: (event: string, handler: Handler) => { handlers.set(event, handler); },
  } as unknown as ExtensionAPI;

  status(pi);
  handlers.get("session_start")?.({ type: "session_start" }, context);
  if (!footerFactory) throw new Error("Status extension did not register a footer");
  if (!editorFactory) throw new Error("Status extension did not register an editor");

  const editor = editorFactory(
    { requestRender: vi.fn(), terminal: { rows: 24 } },
    {
      borderColor: options.borderColor ?? ((text: string) => text),
      selectList: {
        selectedPrefix: (text: string) => text,
        selectedText: (text: string) => text,
        description: (text: string) => text,
        scrollInfo: (text: string) => text,
        noMatch: (text: string) => text,
      },
    },
    { matches: () => false },
  );
  const editorRaw = (width = 160): string => editor.render(width).join("\n");
  const editorRender = (width = 160) => stripTerminalSequences(editorRaw(width));

  const component = footerFactory(
    { requestRender: vi.fn() },
    {
      bold: (text: string) => text,
      // ANSI styles occupy no columns, unlike visible markup in a theme mock.
      fg: (_color: string, text: string) => `\u001b[37m${text}\u001b[39m`,
      getThinkingBorderColor: (level: string) => (text: string) =>
        `\u001b[${level === "high" ? 35 : 36}m${text}\u001b[39m`,
    } as unknown as Theme,
    {
      getGitBranch: () => options.branch ?? null,
      onBranchChange: () => () => undefined,
    },
  );
  disposers.push(() => {
    component.dispose?.();
    handlers.get("session_shutdown")?.({ type: "session_shutdown" }, context);
  });

  const renderRaw = (width = 160) => component.render(width)[0];
  const render = (width = 160) => stripTerminalSequences(renderRaw(width));
  const fire = async (event: string, payload: Record<string, unknown> = {}) => {
    await handlers.get(event)?.({ type: event, ...payload }, context);
  };
  return {
    fire,
    render,
    renderRaw,
    editor,
    editorRender,
    editorRaw,
    component,
    setWorkingVisible,
    setIdle: (next: boolean) => { idle = next; },
    setSessionName: (next: string | undefined) => { sessionName = next; },
    setEntries: (next: SessionEntry[]) => { entries = next; },
    setContextUsage: (next: typeof contextUsage) => { contextUsage = next; },
    setAutoCompact: (next: boolean) => { autoCompact = next; },
  };
}

describe("formatDirectory", () => {
  test("keeps a path unchanged when it fits", () => {
    expect(formatDirectory(`${homedir()}/project`, 32)).toBe("~/project");
  });

  test("marks abbreviated parents and prefers two initials before using one", () => {
    expect(formatDirectory(`${homedir()}/tools/dotfiles/xdg_config/pi/agent/extensions`, 32))
      .toBe("~/to…/do…/xd…/pi/ag…/extensions");
    expect(formatDirectory(`${homedir()}/alpha/bravo/charlie/extensions`, 21))
      .toBe("~/a…/b…/c…/extensions");
  });

  test("preserves a useful initial for hidden directories", () => {
    expect(formatDirectory(`${homedir()}/.config/alpha/extensions`, 20))
      .toBe("~/.c…/al…/extensions");
  });

  test("falls back to a middle ellipsis while preserving the final directory", () => {
    expect(formatDirectory(`${homedir()}/alpha/bravo/charlie/extensions`, 16))
      .toBe("~/…/extensions");
  });
});

function usage(input: number, output: number, cost: number, cacheRead = 0, cacheWrite = 0): Usage {
  return {
    input, output, cacheRead, cacheWrite,
    totalTokens: input + output + cacheRead + cacheWrite,
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: cost },
  };
}

function usageEntry(kind: string, value: Usage): SessionEntry {
  return {
    type: "usage", id: kind, parentId: null, timestamp: "2026-01-01T00:00:00.000Z",
    kind, provider: "other-provider", model: "other-model", usage: value,
  };
}

function assistantEntry(value: Usage): SessionEntry {
  return {
    type: "message", id: "assistant", parentId: null, timestamp: "2026-01-01T00:00:00.000Z",
    message: {
      role: "assistant", content: [], api: "anthropic-messages", provider: "example",
      model: "model", usage: value, stopReason: "stop", timestamp: 0,
    },
  };
}

describe.each([undefined, "1"])("status extension (NO_COLOR=%s)", (noColor) => {
  beforeEach(() => vi.stubEnv("NO_COLOR", noColor));

  test("counts standalone usage of any kind without inventing an assistant cache hit", () => {
    const env = setup({ entries: [
      usageEntry("cache_warm", usage(0, 0, 0.015, 50_000)),
      usageEntry("future-background-operation", { ...usage(120, 30, 0.025), reasoning: 10 }),
    ] });
    const line = env.render(300);
    expect(line).toContain("in 120");
    expect(line).toContain("out 30"); // Reasoning is already included in output.
    expect(line).toContain("$0.040"); // Includes cache-read cost even with zero input/output.
    expect(line).toContain("cache —");
  });

  test("adds background usage to all existing sources and preserves latest assistant cache hit", async () => {
    const base = { id: "summary", parentId: null, timestamp: "2026-01-01T00:00:00.000Z" };
    const entries: SessionEntry[] = [
      assistantEntry(usage(10, 1, 0.001, 90)),
      assistantEntry(usage(20, 2, 0.002, 60, 20)), // Latest prompt is 60% cached.
      {
        ...base, type: "message", message: {
          role: "toolResult", toolCallId: "tool", toolName: "test", content: [],
          isError: false, timestamp: 0, usage: usage(30, 3, 0.003),
        },
      },
      { ...base, type: "compaction", summary: "", firstKeptEntryId: "assistant", tokensBefore: 100, usage: usage(40, 4, 0.004) },
      { ...base, type: "branch_summary", fromId: "assistant", summary: "", usage: usage(50, 5, 0.005) },
    ];
    const env = setup({ entries });
    expect(env.render(300)).toContain("cache 60%");
    env.setEntries([...entries, usageEntry("cache_warm", usage(60, 6, 0.006, 900))]);
    await env.fire("agent_settled");
    const line = env.render(300);
    expect(line).toContain("in 210");
    expect(line).toContain("out 21");
    expect(line).toContain("$0.021");
    expect(line).toContain("cache 60%");

    env.setEntries([...entries, assistantEntry(usage(0, 0, 0)), usageEntry("cache_warm", usage(0, 0, 0.015, 50_000))]);
    await env.fire("turn_end");
    expect(env.render(300)).toContain("cache —"); // Zero-prompt latest assistant still clears it.
  });

  test("tracks UI prompts and compaction lifecycle from Pi 0.84.4", async () => {
    const env = setup();
    expect(env.render()).toContain("READY");
    expect(env.editorRender()).not.toContain("READY");

    await env.fire("ui_prompt_start", { kind: "confirm", reason: "ui_prompt" });
    expect(env.render()).toContain("INPUT NEEDED");

    env.setIdle(false);
    await env.fire("message_update", { assistantMessageEvent: { type: "thinking_delta" } });
    expect(env.render()).toContain("INPUT NEEDED");
    await env.fire("ui_prompt_end", { kind: "confirm", reason: "ui_prompt" });
    expect(env.render()).toContain("THINKING");

    await env.fire("session_before_compact");
    expect(env.render()).toContain("COMPACTING");
    await env.fire("session_compact_failed", { aborted: false });
    expect(env.render()).toContain("ERROR");

    env.setIdle(true);
    await env.fire("session_before_compact");
    await env.fire("session_compact_failed", { aborted: true });
    expect(env.render()).toContain("READY");

    await env.fire("session_before_compact");
    await env.fire("session_compact", { willRetry: false });
    expect(env.render()).toContain("READY");
  });

  test("uses plain thinking-colored bottom border and footer activity", () => {
    const env = setup({ thinking: "high" });
    const lines = env.editorRaw().split("\n");
    expect(stripTerminalSequences(lines[0])).toContain("high • model(example)");
    expect(lines[0]).toContain("\u001b[35mhigh\u001b[39m");
    expect(lines[0]).toContain("\u001b[35m────────────────");
    expect(lines.at(-1)).toBe(`\u001b[35m${"─".repeat(160)}\u001b[39m`);
    expect(env.render(300)).toContain(" ● READY ");
  });

  test("moves model and provider into the editor border while keeping footer metrics", () => {
    const env = setup({ provider: "acme", thinking: "medium" });
    expect(env.render(300)).toContain("READY");
    expect(env.render()).not.toContain("acme");
    expect(env.render()).not.toContain("model");
    expect(env.render()).toContain("ctx");
    expect(env.editorRender()).toContain("model(acme)");
    expect(env.editorRender()).not.toContain("(acme) model");
    expect(env.editorRender()).toContain("medium");
    expect(env.editorRaw(12).split("\n").every((line) => visibleWidth(line) <= 12)).toBe(true);
  });

  test("renders the compressed current directory before the git branch", () => {
    const env = setup({ cwd: `${homedir()}/project`, branch: "main" });
    expect(env.render(300)).toContain(" ● READY  · ~/project · main");
  });

  test("shows the session name after the branch and refreshes rename and clear", async () => {
    const env = setup({ cwd: "/project", branch: "master", sessionName: "Fix bookmarks" });
    expect(env.render(300)).toContain("master · Fix bookmarks");
    env.setSessionName("Review status");
    await env.fire("session_info_changed", { name: "Review status" });
    expect(env.render(300)).toContain("master · Review status");
    expect(env.render(300)).not.toContain("Fix bookmarks");
    env.setSessionName(undefined);
    await env.fire("session_info_changed", { name: undefined });
    expect(env.render(300)).not.toContain("Review status");
    expect(env.render(300)).toContain("master");
  });

  test("truncates session names and preserves context metrics at narrow widths", () => {
    const env = setup({ cwd: "/project", sessionName: "会话".repeat(20) });
    expect(env.render(300)).toContain("/project · " + "会话".repeat(7) + "会…");
    expect(env.render(300)).not.toContain("会话".repeat(20));
    expect(env.render(60)).not.toContain("会话");
    expect(env.render(60)).toContain("ctx 12.5%/100k (auto)");
  });

  test("labels only known subscription-backed authentication as sub", () => {
    expect(setup({ oauth: true }).render()).not.toContain("(sub)");
    expect(setup({ oauth: true, subscriptionAuth: true }).render()).toContain("(sub)");
    expect(setup({ provider: "kimi-coding" }).render()).toContain("(sub)");
  });

  test("preserves autocomplete dropdown rows and scroll indicators in editor borders", async () => {
    const env = setup({ thinking: "high" });
    env.editor.setAutocompleteProvider({
      getSuggestions: async () => ({
        items: [
          { value: "help", label: "help" },
          { value: "quit", label: "quit" },
        ],
        prefix: "/",
      }),
      applyCompletion: (lines: string[], cursorLine: number, cursorCol: number) => ({
        lines,
        cursorLine,
        cursorCol,
      }),
    });
    env.editor.handleInput("/");
    await new Promise((resolve) => setTimeout(resolve, 20));

    const rawLines = env.editor.render(80);
    const plainLines = rawLines.map((line: string) => stripTerminalSequences(line));
    expect(plainLines.some((line: string) => line.includes("help"))).toBe(true);
    expect(plainLines.some((line: string) => line.includes("quit"))).toBe(true);
    const quitIndex = plainLines.findIndex((line: string) => line.includes("quit"));
    expect(rawLines[quitIndex - 2]).toBe(`\u001b[35m${"─".repeat(80)}\u001b[39m`);

    // Scroll overflow indicators should survive in both top and bottom borders.
    env.editor.setText(Array.from({ length: 14 }, (_, i) => `line ${i + 1}`).join("\n"));
    env.editor.handleInput("\u001b[A"); // up a few lines to have hidden lines both above and below
    env.editor.handleInput("\u001b[A");
    env.editor.handleInput("\u001b[A");
    env.editor.handleInput("\u001b[A");
    env.editor.handleInput("\u001b[A");
    env.editor.handleInput("\u001b[A");
    const scrolledLines = env.editor.render(80).map((line: string) => stripTerminalSequences(line));
    expect(scrolledLines[0]).toContain("↑");
    expect(scrolledLines[0]).toContain("high • model(example)");
    expect(scrolledLines.at(-1)).toContain("↓");
  });

  test("keeps ERROR activity after agent_settled until a new run starts", async () => {
    const env = setup({ idle: false });
    await env.fire("agent_start");
    await env.fire("message_update", { assistantMessageEvent: { type: "error", reason: "error" } });
    await env.fire("message_end", { message: { role: "assistant", stopReason: "error" } });
    expect(env.render()).toContain("ERROR");

    env.setIdle(true);
    await env.fire("agent_settled");
    expect(env.render()).toContain("ERROR");

    env.setIdle(false);
    await env.fire("agent_start");
    expect(env.render()).toContain("WAITING");
  });

  test("handles fs.watch failures, watcher error events, and null filenames", () => {
    const watchMock = vi.mocked(watch);

    // Synchronous watch failure should not break session_start or active spinner startup.
    watchMock.mockImplementationOnce(() => {
      throw Object.assign(new Error("ENOENT"), { code: "ENOENT" });
    });
    const envOnThrow = setup({ idle: false });
    expect(envOnThrow.render()).toContain("WAITING");

    // Watcher error events should be caught and close the watcher; null filenames should refresh.
    let errorHandler: (() => void) | undefined;
    let watchCallback: ((eventType: string, filename: string | null) => void) | undefined;
    const close = vi.fn();
    watchMock.mockImplementationOnce(((_path: any, _opts: any, cb: any) => {
      watchCallback = cb;
      return {
        close,
        on: (event: string, listener: () => void) => {
          if (event === "error") errorHandler = listener;
        },
      };
    }) as any);

    const env = setup();
    expect(env.render(300)).toContain("(auto)");
    env.setAutoCompact(false);
    watchCallback?.("change", null);
    expect(env.render(300)).not.toContain("(auto)");

    expect(errorHandler).toBeDefined();
    errorHandler?.();
    expect(close).toHaveBeenCalledTimes(1);
  });

  test("refreshes snapshot on session_tree navigation", async () => {
    const env = setup({ entries: [assistantEntry(usage(10, 5, 0.001, 90))] });
    expect(env.render(300)).toContain("ctx 12.5%/100k");
    expect(env.render(300)).toContain("in 10");

    env.setEntries([assistantEntry(usage(200, 40, 0.05, 800))]);
    env.setContextUsage({ percent: 45.0, contextWindow: 100_000, tokens: 45_000 });
    await env.fire("session_tree");
    const line = env.render(300);
    expect(line).toContain("ctx 45.0%/100k");
    expect(line).toContain("in 200");
    expect(line).toContain("$0.050");
  });

  test("restores RUNNING TOOLS on ui_prompt_end while tool calls are still executing", async () => {
    const env = setup({ idle: false });
    await env.fire("tool_execution_start", { toolCallId: "tool-1" });
    expect(env.render()).toContain("RUNNING TOOLS");

    await env.fire("ui_prompt_start", { kind: "confirm", reason: "ui_prompt" });
    expect(env.render()).toContain("INPUT NEEDED");

    await env.fire("ui_prompt_end", { kind: "confirm", reason: "ui_prompt" });
    expect(env.render()).toContain("RUNNING TOOLS");
  });

  test("does not scan session entries or read settings in non-TUI mode", async () => {
    const createSpy = vi.spyOn(SettingsManager, "create").mockReturnValue({
      getCompactionEnabled: () => true,
    } as SettingsManager);
    const getEntries = vi.fn(() => []);
    const handlers = new Map<string, Handler>();
    const context = {
      cwd: process.cwd(),
      mode: "print",
      model: { provider: "example", id: "model", contextWindow: 100_000 },
      sessionManager: { getEntries },
      modelRegistry: { getProvider: () => undefined, isUsingOAuth: () => false },
      getContextUsage: () => ({ percent: 10, contextWindow: 100_000, tokens: 10_000 }),
      isIdle: () => true,
      isProjectTrusted: () => true,
      ui: { setFooter: vi.fn(), setEditorComponent: vi.fn(), setWorkingVisible: vi.fn() },
    } as unknown as ExtensionContext;
    const pi = {
      getThinkingLevel: () => undefined,
      getSessionName: () => undefined,
      on: (event: string, handler: Handler) => { handlers.set(event, handler); },
    } as unknown as ExtensionAPI;

    status(pi);
    await handlers.get("session_start")?.({ type: "session_start" }, context);
    await handlers.get("turn_end")?.({ type: "turn_end" }, context);
    await handlers.get("agent_settled")?.({ type: "agent_settled" }, context);
    await handlers.get("model_select")?.({ type: "model_select" }, context);
    await handlers.get("thinking_level_select")?.({ type: "thinking_level_select" }, context);
    await handlers.get("session_info_changed")?.({ type: "session_info_changed" }, context);
    await handlers.get("session_tree")?.({ type: "session_tree" }, context);

    expect(createSpy).not.toHaveBeenCalled();
    expect(getEntries).not.toHaveBeenCalled();
  });

  test("cycles 4-frame spinners smoothly without skipping frames across timer wrap", async () => {
    vi.useFakeTimers();
    try {
      const env = setup({ idle: false });
      await env.fire("message_update", { assistantMessageEvent: { type: "thinking_start" } });
      const glyphs: string[] = [];
      for (let i = 0; i < 12; i++) {
        const match = env.render(300).match(/([∼≈≋]) THINKING/);
        glyphs.push(match?.[1] ?? "");
        vi.advanceTimersByTime(80);
      }
      expect(glyphs).toEqual(["∼", "≈", "≋", "≈", "∼", "≈", "≋", "≈", "∼", "≈", "≋", "≈"]);
    } finally {
      vi.useRealTimers();
    }
  });

  test("avoids double-wrapping editorTheme.borderColor and trailing spaces when metadata is empty", () => {
    const env = setup({
      thinking: undefined,
      model: undefined,
      borderColor: (text: string) => `[${text}]`,
    });
    env.component.dispose?.();
    const lines = env.editor.render(20);
    expect(lines[0]).toBe(`[${"─".repeat(20)}]`);
    expect(lines.at(-1)).toBe(`[${"─".repeat(20)}]`);
    expect(lines[0]).not.toContain("[[");
    expect(lines.at(-1)).not.toContain("[[");
  });

  test("guards non-finite cache fields and restores working visibility on shutdown", async () => {
    const infiniteCache = {
      input: 100,
      output: 20,
      cacheRead: Number.POSITIVE_INFINITY,
      cacheWrite: 0,
      totalTokens: 120,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0.01 },
    };
    const env = setup({ entries: [assistantEntry(infiniteCache)] });
    expect(env.render(300)).toContain("cache 0%");
    expect(env.render(300)).not.toContain("NaN");

    const missingCacheWrite = {
      input: 100,
      output: 20,
      cacheRead: 100,
      cacheWrite: undefined as unknown as number,
      totalTokens: 220,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0.01 },
    };
    env.setEntries([assistantEntry(missingCacheWrite)]);
    await env.fire("turn_end");
    expect(env.render(300)).toContain("cache 50%");

    await env.fire("session_shutdown");
    expect(env.setWorkingVisible).toHaveBeenCalledWith(true);
  });

  test("returns to READY on manual session_compact even while ctx.isIdle() is still false", async () => {
    const env = setup();
    // Pi clears _compactionAbortController after emitting session_compact, so isIdle() is false during the event.
    env.setIdle(false);
    await env.fire("session_before_compact", { reason: "manual", willRetry: false });
    expect(env.render()).toContain("COMPACTING");

    await env.fire("session_compact", { reason: "manual", willRetry: false });
    expect(env.render()).toContain("READY");
  });

  test("keeps WAITING after auto-compaction until agent_settled when idle", async () => {
    const env = setup({ idle: false });
    await env.fire("agent_start");
    await env.fire("session_before_compact", { reason: "threshold", willRetry: false });
    expect(env.render()).toContain("COMPACTING");

    await env.fire("session_compact", { reason: "threshold", willRetry: false });
    expect(env.render()).toContain("WAITING");

    env.setIdle(true);
    await env.fire("agent_settled");
    expect(env.render()).toContain("READY");
  });

  test("ignores compaction precondition failures before session_before_compact", async () => {
    const env = setup();
    expect(env.render()).toContain("READY");

    await env.fire("session_compact_failed", { reason: "manual", aborted: false, willRetry: false });
    expect(env.render()).toContain("READY");
  });

  test("preserves underlying ERROR and COMPACTING across ui_prompt overlay", async () => {
    const env = setup({ idle: false });
    await env.fire("agent_start");
    await env.fire("message_end", { message: { role: "assistant", stopReason: "error" } });
    env.setIdle(true);
    await env.fire("agent_settled");
    expect(env.render()).toContain("ERROR");

    // Opening and dismissing a UI prompt while idle must not clear ERROR.
    await env.fire("ui_prompt_start", { kind: "select", reason: "ui_prompt" });
    expect(env.render()).toContain("INPUT NEEDED");
    await env.fire("ui_prompt_end", { kind: "select", reason: "ui_prompt" });
    expect(env.render()).toContain("ERROR");

    // Confirmation prompt inside session_before_compact must restore COMPACTING.
    env.setIdle(false);
    await env.fire("session_before_compact", { reason: "manual", willRetry: false });
    await env.fire("ui_prompt_start", { kind: "confirm", reason: "ui_prompt" });
    expect(env.render()).toContain("INPUT NEEDED");
    await env.fire("ui_prompt_end", { kind: "confirm", reason: "ui_prompt" });
    expect(env.render()).toContain("COMPACTING");

    // Background error + settle while prompt is open must surface ERROR on prompt close.
    await env.fire("session_compact", { reason: "manual", willRetry: false });
    env.setIdle(false);
    await env.fire("before_agent_start");
    await env.fire("ui_prompt_start", { kind: "custom", reason: "ui_prompt" });
    await env.fire("message_end", { message: { role: "assistant", stopReason: "error" } });
    env.setIdle(true);
    await env.fire("agent_settled");
    expect(env.render()).toContain("INPUT NEEDED");
    await env.fire("ui_prompt_end", { kind: "custom", reason: "ui_prompt" });
    expect(env.render()).toContain("ERROR");
  });

  test("transitions to WAITING on before_agent_start and clears ERROR on session_tree when idle", async () => {
    const env = setup();
    env.setIdle(false);
    await env.fire("before_agent_start");
    expect(env.render()).toContain("WAITING");

    await env.fire("message_end", { message: { role: "assistant", stopReason: "error" } });
    env.setIdle(true);
    await env.fire("agent_settled");
    expect(env.render()).toContain("ERROR");

    await env.fire("session_tree");
    expect(env.render()).toContain("READY");
  });
});

test("treats empty NO_COLOR as unset per no-color.org", () => {
  vi.stubEnv("NO_COLOR", "");
  const env = setup();
  expect(env.renderRaw(300)).toContain("\u001b[38;2;");
});
