import { describe, expect, test, vi } from "vitest";
import { setup } from "./harness.ts";

describe("task lifecycle", () => {
  test("foreground disposes and bounded get returns while a background job runs", async () => {
    const foreground = setup();
    const running = foreground.invoke({ action: "run", agent: "scout", objective: "Once" });
    await vi.waitFor(() => expect(foreground.fake.controllers[0]?.starts).toHaveLength(1));
    foreground.fake.controllers[0].settle();
    await running;
    expect(foreground.fake.controllers[0].closeCalls).toBe(1);

    const background = setup({ ids: ["job", "private"] });
    await background.invoke({ action: "run", agent: "scout", objective: "Long", background: true });
    expect((await background.invoke({ action: "get", jobId: "job", waitMs: 1 })).details).toMatchObject({ status: "running" });
    await background.extension.shutdown();
  });
});
