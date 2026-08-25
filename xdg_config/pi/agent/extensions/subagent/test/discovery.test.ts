import { describe, expect, test, vi } from "vitest";
import { mkdirSync, realpathSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import {
  buildWakeWordSnippet,
  loadSubagentOverrides,
  SUBAGENT_COMPLETION_MESSAGE,
  registerSubagentExtension,
  validateAuthEnvAllowlist,
  temporaryDirectory,
  writeAgent,
  deferred,
  FakeController,
  fakeFactory,
  harness,
  context,
  setup,
  startIdle,
} from "./harness.ts";

describe("subagent discovery", () => {
  test("loads missing settings as no overrides and malformed JSON as a collected error", () => {
    expect(loadSubagentOverrides(join(temporaryDirectory("pi-subagent-settings-"), "missing.json"))).toEqual({ errors: [] });

    const settingsPath = join(temporaryDirectory("pi-subagent-settings-"), "settings.json");
    writeFileSync(settingsPath, "{");

    const loaded = loadSubagentOverrides(settingsPath);
    expect(loaded.overrides).toBeUndefined();
    expect(loaded.errors).toHaveLength(1);
    expect(loaded.errors[0].filePath).toBe("settings.json:subagents");
  });

  test("validates and deduplicates credential environment names", () => {
    expect(validateAuthEnvAllowlist([" OPENROUTER_API_KEY ", "OPENROUTER_API_KEY", "_PRIVATE"])).toEqual([
      "OPENROUTER_API_KEY",
      "_PRIVATE",
    ]);
    expect(validateAuthEnvAllowlist(undefined)).toBeUndefined();
    for (const invalid of ["", "lowercase", "9KEY", "API-KEY", "API_KEY\nOTHER"]) {
      expect(() => validateAuthEnvAllowlist([invalid])).toThrow("Invalid subagent auth environment variable name");
    }
  });

  test("discovers agents and builds a canonical, guided work order with declared tools", async () => {
    const env = setup({ ids: ["run-fixed", "operation-fixed"] });
    writeFileSync(join(env.root, "AGENTS.md"), "Project guidance");
    const running = env.invoke({ action: "run", agent: "scout", task: "Find auth", deadlineMs: 1_000 });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    const options = env.fake.controllers[0].starts[0].options;
    const canonicalRoot = realpathSync(env.root);
    expect(env.extension.getTool().description).toContain("scout: Inspect files");
    expect(env.extension.getTool().description).toContain("startup catalog");
    expect(env.extension.getTool().description).toContain("call list only to refresh or diagnose it");
    expect(env.extension.getTool().description).toContain("parent owns decomposition");
    expect(env.extension.getTool().description).not.toContain("NEVER list");
    expect(env.extension.getTool().description).not.toContain("MANDATORY BEFORE any read/bash");
    expect(env.extension.getTool().promptSnippet).toContain("registered agents (scout)");
    expect(env.extension.getTool().promptSnippet).toContain("simple lookups");
    expect(env.extension.getTool().promptSnippet).toContain("routine check reruns");
    expect(env.extension.getTool().promptSnippet).toContain("use the startup catalog directly");
    expect(env.extension.getTool().promptSnippet).toContain("do not call list before a known agent");
    expect(env.extension.getTool().promptSnippet).not.toContain("Inspect files");
    expect(env.extension.getTool().promptSnippet).not.toContain("NEVER list");
    expect(env.extension.getTool().promptGuidelines).toEqual(expect.arrayContaining([
      expect.stringContaining("decompose the bounded work rather than forwarding the raw user prompt"),
      expect.stringContaining("child has fresh context"),
      expect.stringContaining("Outcome, Scope, Starting evidence"),
      expect.stringContaining("Use run for one-shots"),
      expect.stringContaining("deadlineMs"),
      expect.stringContaining("at most three independent one-shots"),
      expect.stringContaining("Treat results as handoffs, not proof"),
      expect.stringContaining("instead of repeating the same reads/searches"),
    ]));
    expect(options).toMatchObject({
      cwd: canonicalRoot,
      runId: "run-fixed",
      operationId: "operation-fixed",
      parentSessionId: "parent-session",
      agent: { name: "scout", tools: ["read", "grep"] },
      workOrder: {
        goal: "Find auth",
        scope: [canonicalRoot],
        constraints: expect.arrayContaining(["Do not delegate to another agent."]),
        returnFormat: expect.stringContaining("concise result"),
        projectGuidance: [`Guidance from ${join(canonicalRoot, "AGENTS.md")}:\nProject guidance`],
      },
    });
    env.fake.controllers[0].settle(0, "completed", "Located auth.");
    const settledRun = await running;
    expect(settledRun.details).toMatchObject({ status: "completed", summary: "Located auth." });
    expect((settledRun.details as { elapsedMs?: unknown }).elapsedMs).toBeTypeOf("number");
    expect(env.fake.controllers[0].closeCalls).toBe(1);
  });

  test("applies startup settings overrides to catalog list and spawn options", async () => {
    const settingsPath = join(temporaryDirectory("pi-subagent-settings-"), "settings.json");
    writeFileSync(settingsPath, JSON.stringify({
      subagents: {
        scout: {
          model: "settings/model",
          thinking: "xhigh",
          description: "Settings description",
        },
      },
    }));
    const env = setup({ ids: ["run-fixed", "operation-fixed"], settingsPath });

    expect(env.extension.getTool().description).toContain("scout: Settings description");
    const listed = await env.invoke({ action: "list" });
    expect((listed.content[0] as { text: string }).text).toContain("scout: Settings description");
    expect(listed.details).toMatchObject({
      agents: [{ name: "scout", description: "Settings description", model: "settings/model", thinking: "xhigh" }],
    });

    const run = env.invoke({ action: "run", agent: "scout", task: "Inspect" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    expect(env.fake.controllers[0].starts[0].options.agent).toMatchObject({
      name: "scout",
      model: "settings/model",
      thinking: "xhigh",
      description: "Settings description",
    });
    env.fake.controllers[0].settle();
    await run;
  });

  test("reapplies startup settings overrides after list rediscovers agents", async () => {
    const settingsPath = join(temporaryDirectory("pi-subagent-settings-"), "settings.json");
    writeFileSync(settingsPath, JSON.stringify({ subagents: { reviewer: { description: "Settings review", thinking: "high" } } }));
    const env = setup({ settingsPath });
    writeAgent(env.agents, "reviewer", "File review");

    const listed = await env.invoke({ action: "list" });

    expect((listed.content[0] as { text: string }).text).toContain("reviewer: Settings review");
    expect(listed.details).toMatchObject({
      agents: expect.arrayContaining([
        expect.objectContaining({ name: "reviewer", description: "Settings review", thinking: "high" }),
      ]),
    });
  });

  test("refreshes registry only on list and reports unknown agents without creating a controller", async () => {
    const env = setup();
    writeAgent(env.agents, "reviewer", "Review code");
    expect((await env.invoke({ action: "run", agent: "reviewer", task: "Review" })).isError).toBe(true);
    const listed = await env.invoke({ action: "list" });
    expect((listed.content[0] as { text: string }).text).toContain("reviewer: Review code");
    const run = env.invoke({ action: "run", agent: "reviewer", task: "Review" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    env.fake.controllers[0].settle();
    await run;
    const missing = await env.invoke({ action: "run", agent: "missing", task: "Nope" });
    expect(missing.isError).toBe(true);
    expect((missing.content[0] as { text: string }).text).toContain("Available agents: reviewer, scout");
    expect(env.fake.factory).toHaveBeenCalledOnce();
  });

  test("buildWakeWordSnippet includes every registered name without duplicating catalog descriptions", () => {
    const registry = {
      agents: [
        { name: "scout", description: "Map multiple files" },
        { name: "custom-auditor", description: "Audit bespoke invariants" },
      ] as never[],
      errors: [],
    };
    const snippet = buildWakeWordSnippet(registry);
    expect(snippet).toContain("registered agents (scout, custom-auditor)");
    expect(snippet).not.toContain("Map multiple files");
    expect(snippet).not.toContain("Audit bespoke invariants");
    expect(snippet).not.toContain("reviewer");
    expect(snippet).toContain("simple lookups");
    expect(snippet).toContain("use the startup catalog directly");
    expect(snippet).toContain("do not call list before a known agent");
  });

  test("buildWakeWordSnippet preserves registry order and has a fixed upper bound", () => {
    const registry = {
      agents: [
        { name: "zeta", description: "Z".repeat(500) },
        { name: "alpha", description: "Alpha role" },
      ] as never[],
      errors: [],
    };
    const snippet = buildWakeWordSnippet(registry);
    expect(snippet.indexOf("zeta")).toBeLessThan(snippet.indexOf("alpha"));
    expect(snippet.length).toBeLessThanOrEqual(1_000);
    expect(snippet).not.toContain("Z".repeat(500));
  });

  test("registered tool keeps one catalog and a bounded model-facing contract", async () => {
    const agents = temporaryDirectory("pi-subagent-agents-");
    writeAgent(agents, "scout", "Scout", "read, grep");
    writeAgent(agents, "oracle", "Oracle", "read, grep");
    const extension = harness();
    registerSubagentExtension(extension.pi, {
      agentDirectory: agents,
      controllerFactory: fakeFactory().factory,
      idFactory: () => "id",
      settingsPath: join(temporaryDirectory("pi-subagent-settings-"), "missing.json"),
    });
    const tool = extension.getTool();
    expect(tool.promptSnippet).toContain("registered agents (oracle, scout)");
    expect(tool.promptSnippet).not.toContain("Scout");
    expect(tool.promptSnippet).not.toContain("Oracle");
    expect(tool.promptSnippet).toContain("single-source fact checks in the parent");
    expect(tool.promptSnippet).not.toContain("NEVER list");
    expect(tool.promptSnippet).not.toContain("BEFORE any read/bash");
    expect(tool.description).toContain("startup catalog");
    expect(tool.description).toContain("scout: Scout");
    expect(tool.description).toContain("oracle: Oracle");
    expect(tool.description).toContain("call list only to refresh or diagnose it");
    expect(tool.description).not.toContain("NEVER list");
    const guidelines = tool.promptGuidelines.join("\n");
    expect(guidelines).not.toContain("scout");
    expect(guidelines).not.toContain("oracle");
    expect(guidelines).toContain("at most three independent one-shots");
    expect(guidelines).toContain("no overlapping parent/child or child/child writes");
    expect(guidelines).toContain("always supply a required task-appropriate deadlineMs");
    expect(guidelines).toContain("failed/crashed/interrupted");
    expect(guidelines).toContain("parent MUST NOT read transcript.sessionPath");
    expect(guidelines).toContain("transcript.sessionPath");
    expect(tool.promptSnippet.length).toBeLessThanOrEqual(320);
    expect(guidelines.length).toBeLessThanOrEqual(1_500);
    expect(JSON.stringify({
      description: tool.description,
      parameters: tool.parameters,
      promptSnippet: tool.promptSnippet,
      promptGuidelines: tool.promptGuidelines,
    }).length).toBeLessThanOrEqual(5_000);
  });

});
