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
});
