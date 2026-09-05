import { afterEach, describe, expect, test, vi } from "vitest";

import { context, harness, registerSubagentExtension, temporaryDirectory, writeAgent } from "./harness.ts";
import { fakeFactory } from "./harness.ts";

const EXACT_SECRET = "output-integration-exact-secret-7f3a";
const GENERIC_TOKEN = `ghp_${"a".repeat(24)}`;

afterEach(() => {
  delete process.env.PI_OUTPUT_INT_SECRET;
  vi.useRealTimers();
});

function setupWithRedaction(ids: string[]) {
  process.env.PI_OUTPUT_INT_SECRET = EXACT_SECRET;
  const root = temporaryDirectory("pi-subagent-project-");
  const agents = temporaryDirectory("pi-subagent-agents-");
  writeAgent(agents);
  const extension = harness();
  const fake = fakeFactory();
  registerSubagentExtension(extension.pi, {
    agentDirectory: agents,
    controllerFactory: fake.factory,
    idFactory: () => ids.shift()!,
    credentialRedactionEnvNames: ["PI_OUTPUT_INT_SECRET"],
  });
  const invoke = (params: Record<string, unknown>) => extension.getTool().execute(
    "call", params as never, undefined, undefined, context(root),
  );
  return { root, extension, fake, invoke };
}

function deepKeys(value: unknown, keys: string[] = []): string[] {
  if (Array.isArray(value)) {
    for (const entry of value) deepKeys(entry, keys);
    return keys;
  }
  if (value && typeof value === "object") {
    for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
      keys.push(key);
      deepKeys(entry, keys);
    }
  }
  return keys;
}

function expectSecretRedacted(result: { content: Array<{ text: string }>; details: unknown }): void {
  expect(result.content.map((part) => part.text).join("\n")).not.toContain(EXACT_SECRET);
  expect(JSON.stringify(result.details)).not.toContain(EXACT_SECRET);
}

describe("output integration through response projection", () => {
  test("redacts credentials from collapsed and expanded invocation rows", () => {
    const env = setupWithRedaction([]);
    const tool = env.extension.getTool();
    const args = {
      action: "run",
      agent: "scout",
      task: `Inspect exact=${EXACT_SECRET} token=${GENERIC_TOKEN}`,
    };
    const theme = {
      fg: (_color: string, text: string) => text,
      bg: (_color: string, text: string) => text,
      bold: (text: string) => text,
    } as never;
    for (const expanded of [false, true]) {
      const rendered = tool.renderCall!(args as never, theme, {
        args,
        expanded,
        isError: false,
        state: {},
        invalidate: vi.fn(),
      } as never).render(200).join("\n");
      expect(rendered).not.toContain(EXACT_SECRET);
      expect(rendered).not.toContain(GENERIC_TOKEN);
    }
  });

  test("redacts credentials from the background activity center task", async () => {
    const env = setupWithRedaction(["job", "operation"]);
    let widgetFactory: unknown;
    const uiContext = {
      ...context(env.root),
      hasUI: true,
      ui: {
        setWidget(_id: string, content: unknown) { widgetFactory = content; },
        setStatus() {},
      },
    } as never;
    await env.extension.getTool().execute("call", {
      action: "run",
      agent: "scout",
      task: `Inspect exact=${EXACT_SECRET} token=${GENERIC_TOKEN}`,
      background: true,
    } as never, undefined, undefined, uiContext);
    expect(typeof widgetFactory).toBe("function");
    const theme = {
      fg: (_color: string, text: string) => text,
      bold: (text: string) => text,
    };
    const widget = (widgetFactory as (tui: unknown, theme: unknown) => { render(width: number): string[] })(undefined, theme);
    const rendered = widget.render(200).join("\n");
    expect(rendered).not.toContain(EXACT_SECRET);
    expect(rendered).not.toContain(GENERIC_TOKEN);
    await env.extension.shutdown();
  });

  test("settled handoff strips internal identities and secrets within serialization bounds", async () => {
    const env = setupWithRedaction(["job", "private"]);
    const longSection = "evidence-line\n".repeat(400);
    await env.invoke({
      action: "run",
      agent: "scout",
      task: `Inspect auth. exact=${EXACT_SECRET} token=${GENERIC_TOKEN}`,
      background: true,
    });
    env.fake.controllers[0].starts[0].options.onProgress?.({
      summary: "reviewing auth",
      timeline: [{ kind: "tool", id: "t1", summary: "read auth.ts", status: "completed" }],
      tools: { earlierCount: 0, history: [], active: [] },
    });
    env.fake.controllers[0].settle(
      0,
      "completed",
      `## Summary\nDone with exact=${EXACT_SECRET} and ${GENERIC_TOKEN}\n## Changes\nEdited auth.ts\n## Evidence\n${longSection}\n## Validation\nvitest green\n## Risks\nNone`,
    );
    const result = await env.invoke({ action: "get", ref: "#1", waitMs: 1_000 });
    const content = (result.content as Array<{ text: string }>).map((part) => part.text).join("");
    // Serialization bound for the parent model context.
    expect(content.length).toBeLessThanOrEqual(32_000);
    // No credential material reaches the model projection.
    expect(content).not.toContain(EXACT_SECRET);
    expect(content).not.toContain(GENERIC_TOKEN);
    // No internal identities cross the model boundary as structured keys.
    const parsed = JSON.parse(content) as unknown;
    const keys = deepKeys(parsed);
    for (const internal of ["transcript", "sessionPath", "sessionId", "operationId", "processInstanceId", "runId", "jobId", "timeline", "toolProgress", "revision"]) {
      expect(keys).not.toContain(internal);
    }
    // The projected handoff itself stays within the 16K handoff budget.
    const summary = (parsed as { summary?: string }).summary ?? "";
    expect(summary.length).toBeLessThanOrEqual(16_000);
    expect(summary).not.toContain(EXACT_SECRET);
    // Human-facing details keep the full diagnostic record.
    expect(result.details).toMatchObject({ ref: "#1", status: "idle", turnStatus: "completed" });
    expect(result.details).toHaveProperty("timeline");
    expect(result.details).toHaveProperty("toolProgress");
    await env.extension.shutdown();
  });

  test("redacts configured credentials from startup, cancel, and close errors", async () => {
    const startup = setupWithRedaction(["startup-job", "startup-op"]);
    startup.fake.factory.mockRejectedValueOnce(new Error(`startup exposed ${EXACT_SECRET}`));
    const startupResult = await startup.invoke({ action: "run", agent: "scout", task: "Start" });
    expect(startupResult).toMatchObject({ isError: true });
    expectSecretRedacted(startupResult);

    const cancelling = setupWithRedaction(["cancel-job", "cancel-op"]);
    await cancelling.invoke({ action: "run", agent: "scout", task: "Cancel", background: true });
    cancelling.fake.controllers[0].interrupt = async () => {
      throw new Error(`cancel exposed ${EXACT_SECRET}`);
    };
    const cancelResult = await cancelling.invoke({ action: "cancel", ref: "#1" });
    expect(cancelResult).toMatchObject({ isError: true });
    expectSecretRedacted(cancelResult);

    const closing = setupWithRedaction(["close-job", "close-op"]);
    await closing.invoke({ action: "run", agent: "scout", task: "Close", background: true });
    closing.fake.controllers[0].close = async () => {
      throw new Error(`close exposed ${EXACT_SECRET}`);
    };
    const closeResult = await closing.invoke({ action: "close", ref: "#1" });
    expect(closeResult).toMatchObject({ isError: true });
    expectSecretRedacted(closeResult);

    await Promise.all([
      startup.extension.shutdown(),
      cancelling.extension.shutdown(),
      closing.extension.shutdown(),
    ]);
  });

  test("oversized handoffs degrade to a bounded truncation envelope", async () => {
    const env = setupWithRedaction(["job", "private"]);
    await env.invoke({ action: "run", agent: "scout", task: "Huge output", background: true });
    // Adversarial renderer payload past every per-field bound: the 32K
    // serialization backstop must still hold on the full chain.
    env.fake.controllers[0].starts[0].options.onProgress?.({
      summary: "drowning in tools",
      timeline: Array.from({ length: 400 }, (_, index) => ({
        kind: "tool" as const,
        id: `t${index}`,
        summary: `read file-${index}.ts ${"y".repeat(200)}`,
        status: "completed" as const,
      })),
      tools: { earlierCount: 392, history: [], active: [] },
    });
    env.fake.controllers[0].settle(0, "completed", "## Summary\nDone");
    const result = await env.invoke({ action: "get", ref: "#1", waitMs: 1_000 });
    const content = (result.content as Array<{ text: string }>).map((part) => part.text).join("");
    // Per-field bounds compose under the serialization budget even for adversarial input.
    expect(content.length).toBeLessThanOrEqual(32_000);
    const parsed = JSON.parse(content) as Record<string, unknown>;
    // Renderer-only timelines never cross the model boundary as structured keys.
    expect(parsed).not.toHaveProperty("timeline");
    expect(parsed).not.toHaveProperty("toolProgress");
    // Human-facing details keep the full diagnostic record.
    expect(result.details).toHaveProperty("timeline");
    expect(result.details).toHaveProperty("toolProgress");
    await env.extension.shutdown();
  });
});
