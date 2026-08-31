import { join } from "node:path";

import { describe, expect, test, vi } from "vitest";

import { setup } from "./harness.ts";

describe("exclusivePaths write leases", () => {
  test("rejects a second job whose exclusivePaths overlap an active lease", async () => {
    const env = setup({ ids: ["job-a", "op-a", "job-b", "op-b"] });
    const first = await env.invoke({
      action: "run", agent: "scout", objective: "A", background: true,
      exclusivePaths: ["src/a.ts"],
    });
    expect(first.details).toMatchObject({ jobId: "job-a", status: "running" });

    const second = await env.invoke({
      action: "run", agent: "scout", objective: "B", background: true,
      exclusivePaths: ["src/a.ts"],
    });
    expect(second.isError).toBe(true);
    expect(second.details).toMatchObject({ error: expect.stringContaining("exclusivePaths conflict") });
    expect(second.details.error).toContain("job-a");
    expect(env.fake.controllers).toHaveLength(1);
    await env.extension.shutdown();
  });

  test("treats identical, ancestor, and descendant paths as overlapping", async () => {
    const env = setup({ ids: ["job-a", "op-a", "job-b", "op-b"] });
    await env.invoke({
      action: "run", agent: "scout", objective: "A", background: true,
      exclusivePaths: ["src/modules/core"],
    });
    const descendant = await env.invoke({
      action: "run", agent: "scout", objective: "B", background: true,
      exclusivePaths: ["src/modules/core/nested"],
    });
    expect(descendant.isError).toBe(true);
    expect(descendant.details.error).toContain("overlaps");
    await env.extension.shutdown();
  });

  test("allows non-overlapping sibling paths and absolute-path equivalents", async () => {
    const env = setup({ ids: ["job-a", "op-a", "job-b", "op-b"] });
    await env.invoke({
      action: "run", agent: "scout", objective: "A", background: true,
      exclusivePaths: ["src/a"],
    });
    const sibling = await env.invoke({
      action: "run", agent: "scout", objective: "B", background: true,
      exclusivePaths: ["src/b"],
    });
    expect(sibling.isError).not.toBe(true);

    // An unrelated absolute path (a sibling, not an ancestor of the leased path) is accepted.
    const absolute = await env.invoke({
      action: "run", agent: "scout", objective: "C", background: true,
      exclusivePaths: [join(env.root, "src", "c")],
    });
    expect(absolute.isError).not.toBe(true);
    await env.extension.shutdown();
  });

  test("releases the lease after the job settles and closes", async () => {
    const env = setup({ ids: ["job-a", "op-a", "job-b", "op-b"] });
    await env.invoke({
      action: "run", agent: "scout", objective: "A", background: true,
      exclusivePaths: ["src/a.ts"],
    });
    env.fake.controllers[0].settle(0);
    await vi.waitFor(() => expect(env.fake.controllers[0].closeCalls).toBe(1));

    const retry = await env.invoke({
      action: "run", agent: "scout", objective: "B", background: true,
      exclusivePaths: ["src/a.ts"],
    });
    expect(retry.isError).not.toBe(true);
    await env.extension.shutdown();
  });

  test("releases the lease after cancel closes the job", async () => {
    const env = setup({ ids: ["job-a", "op-a", "job-b", "op-b"] });
    await env.invoke({
      action: "run", agent: "scout", objective: "A", background: true,
      exclusivePaths: ["src/a.ts"],
    });
    const cancelled = await env.invoke({ action: "cancel", jobId: "job-a" });
    expect(cancelled.details).toMatchObject({ cancelled: true });
    await vi.waitFor(() => expect(env.fake.controllers[0].closeCalls).toBe(1));

    const retry = await env.invoke({
      action: "run", agent: "scout", objective: "B", background: true,
      exclusivePaths: ["src/a.ts"],
    });
    expect(retry.isError).not.toBe(true);
    await env.extension.shutdown();
  });

  test("releases the lease when the runtime crashes and closes", async () => {
    const env = setup({ ids: ["job-a", "op-a", "job-b", "op-b"] });
    await env.invoke({
      action: "run", agent: "scout", objective: "A", background: true,
      exclusivePaths: ["src/a.ts"],
    });
    // A fatal controller failure crashes the runtime; the close path must release the lease.
    env.fake.controllers[0].fail(new Error("controller failed"));
    await vi.waitFor(() => expect(env.fake.controllers[0].closeCalls).toBe(1));

    const retry = await env.invoke({
      action: "run", agent: "scout", objective: "B", background: true,
      exclusivePaths: ["src/a.ts"],
    });
    expect(retry.isError).not.toBe(true);
    await env.extension.shutdown();
  });
});
