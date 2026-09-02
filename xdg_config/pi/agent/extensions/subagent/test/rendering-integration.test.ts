import { describe, expect, test, vi } from "vitest";
import { context, setup } from "./harness.ts";

describe("subagent rendering integration", () => {
  test("tool renderer uses only task API fields", () => {
    const tool = setup().extension.getTool();
    const theme = { fg: (_color: string, text: string) => text, bold: (text: string) => text } as never;
    const rendered = tool.renderCall!({ action: "run", agent: "scout", task: "Inspect", background: true } as never, theme, {
      args: {}, isError: false, state: {}, invalidate: vi.fn(),
    } as never).render(200).join("\n");
    expect(rendered).toContain("scout — Inspect");
    expect(rendered).not.toContain("tracking");
  });

  test("foreground run result carries timeline details for expanded rendering", async () => {
    const env = setup();
    const running = env.extension.getTool().execute("call", {
      action: "run", agent: "scout", task: "Inspect timeline",
    }, undefined, undefined, context(env.root));
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].starts[0].options.onProgress?.({
      summary: "read result.ts done",
      timeline: [
        { kind: "tool", id: "tool-1", summary: "read result.ts", status: "completed" },
        { kind: "thinking", text: "private reasoning" },
      ],
    });
    env.fake.controllers[0].settle();
    const result = await running;
    expect((result.details as Record<string, unknown>).timeline).toEqual([
      { kind: "tool", id: "tool-1", summary: "read result.ts", status: "completed" },
      { kind: "thinking", text: "private reasoning" },
    ]);
    await env.extension.shutdown();
  });

  test("foreground execution lives in the activity center until settlement", async () => {
    const env = setup();
    let widget: unknown;
    const ctx = {
      ...context(env.root),
      hasUI: true,
      ui: {
        setWidget(_id: string, content: unknown) { widget = content; },
        setStatus() {},
      },
    } as never;
    const running = env.extension.getTool().execute("call", {
      action: "run", agent: "scout", task: "Inspect the complete authentication flow",
    }, undefined, undefined, ctx);
    await vi.waitFor(() => expect(typeof widget).toBe("function"));
    const component = (widget as (tui: unknown, theme: unknown) => { render(width: number): string[] })(undefined, {
      fg: (_color: string, value: string) => value,
      bold: (value: string) => value,
    });
    const rendered = component.render(100).join("\n");
    expect(rendered).toContain("#1 scout");
    expect(rendered).toContain("Inspect the complete authentication flow");
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle();
    await running;
    expect(widget).toBeUndefined();
    await env.extension.shutdown();
  });
});
