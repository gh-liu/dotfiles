import { homedir } from "node:os";
import { afterEach, describe, expect, test, vi } from "vitest";

import { SettingsManager, type ExtensionAPI, type ExtensionContext, type SessionEntry, type Theme } from "@earendil-works/pi-coding-agent";
import type { Usage } from "@earendil-works/pi-ai";

// Keep footer tests independent of user settings and filesystem watcher timing.
vi.mock("node:fs", async (importOriginal) => ({
  ...await importOriginal<typeof import("node:fs")>(),
  watch: vi.fn(() => ({ close: vi.fn() })),
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
  subscriptionAuth?: boolean;
  thinking?: "minimal" | "low" | "medium" | "high" | "xhigh" | "max";
  cwd?: string;
  branch?: string | null;
  entries?: SessionEntry[];
} = {}) {
  vi.spyOn(SettingsManager, "create").mockReturnValue({
    getCompactionEnabled: () => true,
  } as SettingsManager);
  let entries = options.entries ?? [];
  const handlers = new Map<string, Handler>();
  let footerFactory: ((tui: any, theme: Theme, footerData: any) => any) | undefined;
  let editorFactory: ((tui: any, theme: any, keybindings: any) => any) | undefined;
  let idle = options.idle ?? true;
  const model = {
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
    getContextUsage: () => ({ percent: 12.5, contextWindow: 100_000, tokens: 12_500 }),
    isIdle: () => idle,
    isProjectTrusted: () => true,
    ui: {
      setFooter: (factory: typeof footerFactory) => { footerFactory = factory; },
      setEditorComponent: (factory: typeof editorFactory) => { editorFactory = factory ?? undefined; },
      setWorkingVisible: vi.fn(),
    },
  } as unknown as ExtensionContext;
  const pi = {
    getThinkingLevel: () => options.thinking,
    on: (event: string, handler: Handler) => { handlers.set(event, handler); },
  } as unknown as ExtensionAPI;

  status(pi);
  handlers.get("session_start")?.({ type: "session_start" }, context);
  if (!footerFactory) throw new Error("Status extension did not register a footer");
  if (!editorFactory) throw new Error("Status extension did not register an editor");

  const editor = editorFactory(
    { requestRender: vi.fn(), terminal: { rows: 24 } },
    { borderColor: (text: string) => text, selectList: {} },
    {},
  );
  const editorRender = (width = 160) => editor.render(width).map((line) => line.replace(/\u001b\[[0-9;]*m/g, "")).join("\n");

  const component = footerFactory(
    { requestRender: vi.fn() },
    {
      bold: (text: string) => text,
      fg: (color: string, text: string) => `<${color}>${text}</${color}>`,
      getThinkingBorderColor: (level: string) => (text: string) => `<thinking-${level}>${text}</thinking-${level}>`,
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

  const render = (width = 160) => component.render(width)[0].replace(/\u001b\[[0-9;]*m/g, "");
  const fire = async (event: string, payload: Record<string, unknown> = {}) => {
    await handlers.get(event)?.({ type: event, ...payload }, context);
  };
  return {
    fire,
    render,
    editorRender,
    setIdle: (next: boolean) => { idle = next; },
    setEntries: (next: SessionEntry[]) => { entries = next; },
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

describe("status extension", () => {
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
    expect(env.render()).toContain("WAITING");

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
    vi.stubEnv("NO_COLOR", "1");
    const env = setup({ thinking: "high" });
    const border = env.editorRender();

    const lines = border.split("\n");
    expect(lines[0]).toContain("<thinking-high>high</thinking-high> • <text>model</text><muted>(example)</muted>");
    expect(lines[0]).toContain("<thinking-high>────────────────");
    expect(lines.at(-1)).not.toContain("READY");
    expect(lines.at(-1)).toContain("<thinking-high>────────────────");
    expect(env.render(300)).toContain("<text> ● READY </text>");
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
    expect(env.editorRender(12).split("\n").every((line) => {
      const plain = line.replace(/<[^>]+>/g, "");
      return [...plain].length <= 12;
    })).toBe(true);
  });

  test("renders the compressed current directory before the git branch", () => {
    vi.stubEnv("NO_COLOR", "1");
    const env = setup({ cwd: `${homedir()}/project`, branch: "main" });
    expect(env.render(300)).toContain(
      "<text> ● READY </text> · <muted>~/project</muted> · <success>main</success>",
    );
  });

  test("labels only known subscription-backed authentication as sub", () => {
    expect(setup({ oauth: true }).render()).not.toContain("(sub)");
    expect(setup({ oauth: true, subscriptionAuth: true }).render()).toContain("(sub)");
    expect(setup({ provider: "kimi-coding" }).render()).toContain("(sub)");
  });
});
