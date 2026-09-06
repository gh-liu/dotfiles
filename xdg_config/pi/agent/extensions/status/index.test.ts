import { homedir } from "node:os";
import { afterEach, describe, expect, test, vi } from "vitest";

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import status from "./index.ts";

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
} = {}) {
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
    getEntries: () => [],
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
  };
}

describe("status extension", () => {
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
