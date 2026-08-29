import { afterEach, describe, expect, test, vi } from "vitest";

import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import status from "./index.ts";

type Handler = (event: any, context: ExtensionContext) => void | Promise<void>;

const disposers: Array<() => void> = [];

afterEach(() => {
  for (const dispose of disposers.splice(0)) dispose();
  vi.restoreAllMocks();
});

function setup(options: {
  idle?: boolean;
  oauth?: boolean;
  provider?: string;
  subscriptionAuth?: boolean;
} = {}) {
  const handlers = new Map<string, Handler>();
  let footerFactory: ((tui: any, theme: Theme, footerData: any) => any) | undefined;
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
    cwd: process.cwd(),
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
      setWorkingVisible: vi.fn(),
    },
  } as unknown as ExtensionContext;
  const pi = {
    getThinkingLevel: () => undefined,
    on: (event: string, handler: Handler) => { handlers.set(event, handler); },
  } as unknown as ExtensionAPI;

  status(pi);
  handlers.get("session_start")?.({ type: "session_start" }, context);
  if (!footerFactory) throw new Error("Status extension did not register a footer");

  const component = footerFactory(
    { requestRender: vi.fn() },
    {
      bold: (text: string) => text,
      fg: (_color: string, text: string) => text,
      getThinkingBorderColor: () => (text: string) => text,
    } as unknown as Theme,
    {
      getGitBranch: () => null,
      onBranchChange: () => () => undefined,
    },
  );
  disposers.push(() => {
    component.dispose?.();
    handlers.get("session_shutdown")?.({ type: "session_shutdown" }, context);
  });

  const render = () => component.render(160)[0].replace(/\u001b\[[0-9;]*m/g, "");
  const fire = async (event: string, payload: Record<string, unknown> = {}) => {
    await handlers.get(event)?.({ type: event, ...payload }, context);
  };
  return { fire, render, setIdle: (next: boolean) => { idle = next; } };
}

describe("status extension", () => {
  test("tracks UI prompts and compaction lifecycle from Pi 0.84.4", async () => {
    const env = setup();
    expect(env.render()).toContain("READY");

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

  test("labels only known subscription-backed authentication as sub", () => {
    expect(setup({ oauth: true }).render()).not.toContain("(sub)");
    expect(setup({ oauth: true, subscriptionAuth: true }).render()).toContain("(sub)");
    expect(setup({ provider: "kimi-coding" }).render()).toContain("(sub)");
  });
});
