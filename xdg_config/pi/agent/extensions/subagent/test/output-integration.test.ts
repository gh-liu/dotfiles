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
  return { extension, fake, invoke };
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

describe("output integration through response projection", () => {
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
