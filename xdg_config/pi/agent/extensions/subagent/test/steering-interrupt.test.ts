import { describe, expect, test } from "vitest";
import { setup } from "./harness.ts";

describe("cancellation guard", () => {
  test("cancel targets only the internally active operation and is idempotent", async () => {
    const env = setup({ ids: ["job", "private"] });
    await env.invoke({ action: "run", agent: "scout", objective: "Long", background: true });
    expect((await env.invoke({ action: "cancel", jobId: "job" })).details).toMatchObject({ cancelled: true, status: "interrupted" });
    expect(env.fake.controllers[0].interruptCalls).toEqual(["private"]);
    expect((await env.invoke({ action: "cancel", jobId: "job" })).details).toMatchObject({ cancelled: false, alreadyTerminal: true });
  });
});
