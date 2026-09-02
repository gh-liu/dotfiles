import { describe, expect, test, vi } from "vitest";
import { setup } from "./harness.ts";

describe("task lifecycle", () => {
  test("foreground stays reusable and bounded get returns while a background turn runs", async () => {
    const foreground = setup();
    const running = foreground.invoke({ action: "run", agent: "scout", task: "Once" });
    await vi.waitFor(() => expect(foreground.fake.controllers[0]?.starts).toHaveLength(1));
    foreground.fake.controllers[0].settle();
    await running;
    expect(foreground.fake.controllers[0].closeCalls).toBe(0);

    const background = setup({ ids: ["job", "private"] });
    await background.invoke({ action: "run", agent: "scout", task: "Long", background: true });
    expect((await background.invoke({ action: "get", ref: "#1", waitMs: 1 })).details).toMatchObject({ status: "running" });
    await background.extension.shutdown();
  });
});
