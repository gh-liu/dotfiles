import { describe, expect, test, vi } from "vitest";
import { setup } from "./harness.ts";

const theme = {
  fg: (_color: string, text: string) => text,
  bold: (text: string) => text,
} as never;

function render(component: { render(width: number): string[] }): string {
  return component.render(100).join("\n");
}

describe("Feature: minimal rendering", () => {
  test("Scenario: invocation rendering is durable, bounded, and non-secret", () => {
    const env = setup({ credentialValues: ["render-secret"] });
    const args = { task: `Inspect ownership\ncredential=render-secret`, opts: { thinking: "low" } };

    const collapsed = render(env.tool.renderCall!(args as never, theme, {
      args,
      expanded: false,
      isError: false,
      state: {},
      invalidate: vi.fn(),
    } as never));
    const expanded = render(env.tool.renderCall!(args as never, theme, {
      args,
      expanded: true,
      isError: false,
      state: {},
      invalidate: vi.fn(),
    } as never));

    expect(collapsed).toContain("Inspect ownership");
    expect(collapsed).toContain("low");
    expect(expanded).not.toContain("render-secret");
    expect(`${collapsed}\n${expanded}`).not.toMatch(/spinner|running/i);
  });

  test.each([
    [{ status: "completed", handoff: "Useful result" }, "completed"],
    [{ status: "failed", error: "Provider failed" }, "failed"],
    [{ status: "interrupted", error: "Parent cancelled" }, "interrupted"],
  ])("Scenario Outline: result rendering distinguishes %s without internals", (payload, label) => {
    const env = setup();
    const result = {
      content: [{ type: "text", text: JSON.stringify(payload) }],
      details: payload,
    };
    const rendered = render(env.tool.renderResult!(result as never, {
      expanded: false,
      isPartial: false,
    }, theme, {
      args: { task: "inspect" },
      expanded: false,
      isError: label === "failed",
      state: {},
      invalidate: vi.fn(),
    } as never));

    expect(rendered).toContain(label);
    expect(rendered).not.toMatch(/sessionPath|operationId|toolCallId|thinking/i);
  });

  test("Scenario: running activity streams into the expanded tool result", async () => {
    const env = setup({ credentialValues: ["stream-secret"] });
    const updates: Array<{ content: Array<{ text: string }>; details: Record<string, unknown> }> = [];
    const delegated = env.execute(
      { task: "Inspect ownership" },
      undefined,
      {},
      (update) => updates.push(update as typeof updates[number]),
    );
    await vi.waitFor(() => expect(env.children).toHaveLength(1));

    env.children[0].progress({
      activity: "bash pnpm test stream-secret",
      earlierCount: 2,
      recent: [
        { kind: "thinking", label: "Thinking", status: "completed" },
        { kind: "tool", label: "read auth.ts", status: "completed" },
      ],
      active: [{ kind: "tool", label: "bash pnpm test stream-secret", status: "running" }],
    });

    expect(updates).toHaveLength(1);
    const expanded = render(env.tool.renderResult!(updates[0] as never, {
      expanded: true,
      isPartial: true,
    }, theme, {
      args: { task: "Inspect ownership" },
      expanded: true,
      isError: false,
      state: {},
      invalidate: vi.fn(),
    } as never));
    const collapsed = render(env.tool.renderResult!(updates[0] as never, {
      expanded: false,
      isPartial: true,
    }, theme, {
      args: { task: "Inspect ownership" },
      expanded: false,
      isError: false,
      state: {},
      invalidate: vi.fn(),
    } as never));

    expect(collapsed).toContain("running · bash pnpm test [REDACTED]");
    expect(collapsed).not.toContain("read auth.ts");
    expect(expanded).toContain("2 earlier activities");
    expect(expanded).toContain("✓ Thinking");
    expect(expanded).toContain("✓ read auth.ts");
    expect(expanded).toContain("◷ bash pnpm test [REDACTED]");
    expect(expanded).not.toContain("stream-secret");

    env.children[0].complete();
    await delegated;
  });
});
