import { describe, expect, test } from "vitest";
import { setup } from "./harness.ts";

describe("turn cancellation", () => {
  test("cancel targets only the internally active operation and is idempotent", async () => {
    const env = setup({ ids: ["job", "private"] });
    await env.invoke({ action: "run", agent: "scout", task: "Long", background: true });
    expect((await env.invoke({ action: "cancel", ref: "#1" })).details).toMatchObject({ cancelled: true, status: "idle", turnStatus: "interrupted" });
    expect(env.fake.controllers[0].interruptCalls).toEqual(["private"]);
    expect((await env.invoke({ action: "cancel", ref: "#1" })).details).toMatchObject({ cancelled: false, alreadyIdle: true });
  });
});
