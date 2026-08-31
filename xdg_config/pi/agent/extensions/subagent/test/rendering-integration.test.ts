import { describe, expect, test, vi } from "vitest";
import { setup } from "./harness.ts";

describe("subagent rendering integration", () => {
  test("tool renderer uses only task API fields", () => {
    const tool = setup().extension.getTool();
    const theme = { fg: (_color: string, text: string) => text, bold: (text: string) => text } as never;
    const rendered = tool.renderCall!({ action: "run", agent: "scout", objective: "Inspect", background: true } as never, theme, {
      args: {}, isError: false, state: {}, invalidate: vi.fn(),
    } as never).render(200).join("\n");
    expect(rendered).toContain("scout — Inspect · tracking in Subagents");
  });
});
