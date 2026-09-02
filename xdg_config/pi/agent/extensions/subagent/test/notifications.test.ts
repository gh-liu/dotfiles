import { describe, expect, test, vi } from "vitest";
import { context, setup } from "./harness.ts";

describe("subagent notifications", () => {
  test("batches successes and notification failure does not alter settled state", async () => {
    const env = setup({ ids: ["a", "pa", "b", "pb"] });
    await env.invoke({ action: "run", agent: "scout", objective: "A", background: true });
    await env.invoke({ action: "run", agent: "scout", objective: "B", background: true });
    env.fake.controllers[0].settle();
    env.fake.controllers[1].settle();
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0].message.details).toMatchObject({ batch: expect.any(Array) });
    expect(env.extension.messages[0].message.details).toMatchObject({ batch: [
      { jobId: "a", ref: "#1" },
      { jobId: "b", ref: "#2" },
    ] });
    expect(env.extension.messages[0].message.content).toContain('#1 scout · completed');
    expect(env.extension.messages[0].message.content).toContain('Use get("#1")');

    const failedDelivery = setup({ ids: ["c", "pc"] });
    vi.spyOn(failedDelivery.extension.pi, "sendMessage").mockImplementation(() => { throw new Error("unavailable"); });
    await failedDelivery.invoke({ action: "run", agent: "scout", objective: "C", background: true });
    failedDelivery.fake.controllers[0].settle();
    await vi.waitFor(async () => expect((await failedDelivery.invoke({ action: "get", jobId: "c" })).details).toMatchObject({ status: "completed" }));
  });

  test("keeps the live row until completion delivery succeeds and retains recovery UI on failure", async () => {
    const runCase = async (failDelivery: boolean) => {
      const env = setup({ ids: ["job", "private"] });
      let widget: unknown;
      const ui = {
        setWidget(_id: string, content: unknown) { widget = content; },
        setStatus() {},
      };
      const ctx = { ...context(env.root), hasUI: true, ui } as never;
      if (failDelivery) vi.spyOn(env.extension.pi, "sendMessage").mockImplementation(() => { throw new Error("unavailable"); });
      else vi.spyOn(env.extension.pi, "sendMessage").mockImplementation((message, options) => {
        env.extension.messages.push({ message: message as never, options: options as never });
        expect(typeof widget).toBe("function");
      });

      await env.extension.getTool().execute("call", {
        action: "run", agent: "scout", objective: "Inspect", background: true,
      }, undefined, undefined, ctx);
      expect(typeof widget).toBe("function");
      env.fake.controllers[0].settle();
      await vi.waitFor(() => {
        if (!failDelivery) {
          expect(widget).toBeUndefined();
          return;
        }
        expect(typeof widget).toBe("function");
        const component = (widget as (tui: unknown, theme: unknown) => { render(width: number): string[] })(undefined, {
          fg: (_color: string, text: string) => text,
          bold: (text: string) => text,
        });
        expect(component.render(100).join("\n")).toContain("#1 scout · reporting failed · use get");
      });
      if (failDelivery) {
        await env.invoke({ action: "get", jobId: "#1" });
        expect(widget).toBeUndefined();
      }
      await env.extension.shutdown();
    };

    await runCase(false);
    await runCase(true);
  });

  test("failed completion cards retain structured handoff fields and recent activity", async () => {
    const env = setup({ ids: ["job", "private"] });
    await env.invoke({ action: "run", agent: "scout", objective: "Review", background: true });
    env.fake.controllers[0].starts[0].options.onProgress?.({
      summary: "reviewing failure",
      timeline: [
        { kind: "thinking", text: "hidden" },
        { kind: "tool", id: "test", summary: "npm test", status: "failed" },
      ],
    });
    env.fake.controllers[0].settle(0, "failed", "## Summary\nTests failed\n## Evidence\nStack trace\n## Risks\nRelease blocked");
    await vi.waitFor(() => expect(env.extension.messages).toHaveLength(1));
    expect(env.extension.messages[0].message.details).toMatchObject({
      status: "failed", summary: "Tests failed", evidence: "Stack trace", risks: "Release blocked",
      recentActivity: ["Thinking", "failed: npm test"],
    });
    await env.extension.shutdown();
  });
});
