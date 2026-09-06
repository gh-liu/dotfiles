import { afterEach, describe, expect, test } from "vitest";

import { context, fakeFactory, harness, registerSubagentExtension, setup, temporaryDirectory, writeAgent } from "./harness.ts";

afterEach(() => {
  delete process.env.PI_LIVE_WIDGET_SECRET;
});

function renderWidgetText(widget: unknown, width = 100): string {
  if (typeof widget !== "function") return "";
  const component = (widget as (tui: unknown, theme: unknown) => { render(w: number): string[] })(undefined, {
    fg: (_color: string, text: string) => text,
    bold: (text: string) => text,
  });
  return component.render(width).join("\n");
}

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

  test("followup on unknown refs is an explicit error through both pipelines", async () => {
    const env = setup({ ids: ["job", "private"] });
    const direct = await env.invoke({ action: "followup", ref: "#99", task: "Fill the gap" });
    expect(direct).toMatchObject({ isError: true });
    expect(direct.details).toMatchObject({ ref: "#99", status: "unknown", unknown: true });
    const live = await env.invokeLive({ action: "followup", ref: "#99", task: "Fill the gap" });
    expect(live).toMatchObject({ isError: true });
    expect(live.details).toMatchObject({ ref: "#99", status: "unknown", unknown: true });
    await env.extension.shutdown();
  });

  test("ref resolution trims whitespace but still rejects #0/#01", async () => {
    const env = setup({ ids: ["job", "private"] });
    await env.invoke({ action: "run", agent: "scout", task: "Work", background: true });
    expect((await env.invoke({ action: "get", ref: " #1" })).details).toMatchObject({ ref: "#1" });
    expect((await env.invoke({ action: "get", ref: "#1 " })).details).toMatchObject({ ref: "#1" });
    expect(await env.invoke({ action: "get", ref: "#0" })).toMatchObject({ isError: true });
    expect((await env.invoke({ action: "get", ref: "#0" })).details).toMatchObject({ status: "unknown", unknown: true });
    expect(await env.invoke({ action: "get", ref: "#01" })).toMatchObject({ isError: true });
    expect((await env.invoke({ action: "get", ref: "#01" })).details).toMatchObject({ status: "unknown", unknown: true });
    await env.extension.shutdown();
  });

  test("live widget task text carries no credential residue", async () => {
    const secret = "EXA_FAKE_KEY_12345";
    process.env.PI_LIVE_WIDGET_SECRET = secret;
    const root = temporaryDirectory("pi-subagent-project-");
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeAgent(agents);
    const extension = harness();
    const fake = fakeFactory();
    registerSubagentExtension(extension.pi, {
      agentDirectory: agents,
      controllerFactory: fake.factory,
      idFactory: (() => { const ids = ["widget-job", "widget-op"]; return () => ids.shift()!; })(),
      credentialRedactionEnvNames: ["PI_LIVE_WIDGET_SECRET"],
    });
    let widget: unknown;
    const ctx = {
      ...context(root), hasUI: true,
      ui: { setWidget(_id: string, content: unknown) { widget = content; }, setStatus() {} },
    } as never;
    await extension.getTool().execute("call", {
      action: "run", agent: "scout", task: `Inspect auth with ${secret} embedded`, background: true,
    }, undefined, undefined, ctx);
    const rendered = renderWidgetText(widget);
    expect(rendered).toContain("Inspect auth");
    expect(rendered).not.toContain(secret);
    await extension.shutdown?.();
  });
});
