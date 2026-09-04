import { describe, expect, test } from "vitest";

import { setup } from "./harness.ts";

describe("unknown session references", () => {
  test("cancel and close on unknown refs are explicit errors; known idle repeats stay idempotent", async () => {
    const env = setup({ ids: ["job", "private"] });
    expect(await env.invoke({ action: "get", ref: "#99" })).toMatchObject({ isError: true });
    expect((await env.invoke({ action: "get", ref: "#99" })).details).toMatchObject({
      ref: "#99",
      status: "unknown",
      unknown: true,
    });
    expect(await env.invoke({ action: "cancel", ref: "#99" })).toMatchObject({ isError: true });
    expect((await env.invoke({ action: "cancel", ref: "#99" })).details).toMatchObject({
      ref: "#99",
      status: "unknown",
      unknown: true,
      cancelled: false,
    });
    expect(await env.invoke({ action: "close", ref: "#99" })).toMatchObject({ isError: true });
    expect((await env.invoke({ action: "close", ref: "#99" })).details).toMatchObject({
      ref: "#99",
      status: "unknown",
      unknown: true,
      closed: false,
    });

    // Live pipeline (agent-core drops a returned isError flag; only the
    // tool_result patch sets the serialized flag): unknown refs must still
    // surface isError:true with structured details intact.
    expect(await env.invokeLive({ action: "get", ref: "#99" })).toMatchObject({ isError: true });
    expect((await env.invokeLive({ action: "get", ref: "#99" })).details).toMatchObject({
      ref: "#99",
      status: "unknown",
      unknown: true,
    });
    expect(await env.invokeLive({ action: "cancel", ref: "#99" })).toMatchObject({ isError: true });
    expect((await env.invokeLive({ action: "cancel", ref: "#99" })).details).toMatchObject({
      ref: "#99",
      status: "unknown",
      unknown: true,
      cancelled: false,
    });
    expect(await env.invokeLive({ action: "close", ref: "#99" })).toMatchObject({ isError: true });
    expect((await env.invokeLive({ action: "close", ref: "#99" })).details).toMatchObject({
      ref: "#99",
      status: "unknown",
      unknown: true,
      closed: false,
    });

    await env.invoke({ action: "run", agent: "scout", task: "Work", background: true });
    expect((await env.invoke({ action: "cancel", ref: "#1" })).details).toMatchObject({ cancelled: true });
    // Known idle repeat through the live pipeline: idempotent success, not an error.
    const repeatCancel = await env.invokeLive({ action: "cancel", ref: "#1" });
    expect(repeatCancel).not.toMatchObject({ isError: true });
    expect(repeatCancel.details).toMatchObject({ cancelled: false, alreadyIdle: true });
    const firstClose = await env.invokeLive({ action: "close", ref: "#1" });
    expect(firstClose).not.toMatchObject({ isError: true });
    expect(firstClose.details).toMatchObject({ closed: true });
    await env.extension.shutdown();
  });
});
