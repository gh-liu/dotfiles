import { describe, expect, test, vi } from "vitest";
import { realpathSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { buildWakeWordSnippet, context, loadSubagentOverrides, setup, temporaryDirectory, validateAuthEnvAllowlist, writeAgent } from "./harness.ts";

describe("subagent discovery", () => {
  test("loads configurable capacity alongside agent overrides", () => {
    const path = join(temporaryDirectory("settings-"), "settings.json");
    writeFileSync(path, JSON.stringify({
      subagent: {
        maxConcurrentRuns: 8,
        subagents: { scout: { model: "vendor/model" } },
      },
    }));

    expect(loadSubagentOverrides(path)).toEqual({
      maxConcurrentRuns: 8,
      overrides: { scout: { model: "vendor/model" } },
      errors: [],
    });
  });

  test.each([0, 9, 1.5, "3", null])("rejects invalid capacity %j", (maxConcurrentRuns) => {
    const path = join(temporaryDirectory("settings-"), "settings.json");
    writeFileSync(path, JSON.stringify({ subagent: { maxConcurrentRuns } }));

    const loaded = loadSubagentOverrides(path);
    expect(loaded.maxConcurrentRuns).toBeUndefined();
    expect(loaded.errors).toHaveLength(1);
    expect(loaded.errors[0]?.error).toContain("integer from 1 to 8");
  });

  test("reports malformed nested overrides without dropping valid capacity", () => {
    const path = join(temporaryDirectory("settings-"), "settings.json");
    writeFileSync(path, JSON.stringify({
      subagent: { maxConcurrentRuns: 5, subagents: [] },
    }));

    const loaded = loadSubagentOverrides(path);
    expect(loaded.maxConcurrentRuns).toBe(5);
    expect(loaded.overrides).toBeUndefined();
    expect(loaded.errors).toHaveLength(1);
    expect(loaded.errors[0]?.error).toContain("must be an object");
  });

  test("reports the removed top-level override location", () => {
    const path = join(temporaryDirectory("settings-"), "settings.json");
    writeFileSync(path, JSON.stringify({ subagents: { scout: { model: "legacy/model" } } }));
    const loaded = loadSubagentOverrides(path);
    expect(loaded.overrides).toBeUndefined();
    expect(loaded.errors[0]?.error).toContain("moved to settings.json:subagent.subagents");
  });

  test("collects malformed settings and validates credential names", () => {
    const path = join(temporaryDirectory("settings-"), "settings.json");
    writeFileSync(path, "{");
    expect(loadSubagentOverrides(path).errors).toHaveLength(1);
    expect(validateAuthEnvAllowlist([" KEY ", "KEY"])).toEqual(["KEY"]);
    expect(() => validateAuthEnvAllowlist(["bad-name"])).toThrow();
  });

  test("builds canonical guided work orders with effective agent settings", async () => {
    const settingsPath = join(temporaryDirectory("settings-"), "settings.json");
    writeFileSync(settingsPath, JSON.stringify({ subagent: { subagents: { scout: { model: "vendor/model", thinking: "high" } } } }));
    const env = setup({ ids: ["job", "private"], settingsPath });
    writeFileSync(join(env.root, "AGENTS.md"), "Project guidance");
    const running = env.invoke({ action: "run", agent: "scout", objective: "Find auth" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    expect(env.fake.controllers[0].starts[0].options).toMatchObject({
      cwd: realpathSync(env.root),
      agent: { name: "scout", model: "vendor/model", thinking: "high", tools: ["read", "grep"] },
      workOrder: { goal: "Find auth", projectGuidance: [expect.stringContaining("Project guidance")] },
    });
    env.fake.controllers[0].settle();
    await running;
  });

  test("wake snippet delegates only when fresh context provides a concrete benefit", () => {
    const snippet = buildWakeWordSnippet({ agents: [{ name: "scout", description: "Inspect", tools: [], systemPrompt: "" }], errors: [] });
    expect(snippet).toContain("Delegate to registered agents");
    expect(snippet).toContain("registered agents (scout)");
    expect(snippet).toContain("fresh context, specialization, independent judgment, or parallel work");
    expect(snippet).toContain("delegation would only add handoff overhead");
    expect(snippet).toContain("decomposition, coordination, integration, and final verification");
    expect(snippet.length).toBeLessThanOrEqual(1_000);
  });

  test("inherits the parent model, while an explicit override wins", async () => {
    const inherited = setup({ ids: ["job", "private"] });
    const inheritedContext = { ...context(inherited.root), model: { provider: "parent", id: "model" } };
    const run = inherited.extension.getTool().execute("call", { action: "run", agent: "scout", objective: "Inspect", deadlineMs: 60_000 } as never, undefined, undefined, inheritedContext as never);
    await vi.waitFor(() => expect(inherited.fake.controllers[0]?.starts).toHaveLength(1));
    expect(inherited.fake.controllers[0].starts[0].options.agent.model).toBe("parent/model");
    inherited.fake.controllers[0].settle();
    await run;

    const settingsPath = join(temporaryDirectory("settings-"), "settings.json");
    writeFileSync(settingsPath, JSON.stringify({ subagent: { subagents: { scout: { model: "override/model" } } } }));
    const overridden = setup({ settingsPath });
    const overrideRun = overridden.extension.getTool().execute("call", { action: "run", agent: "scout", objective: "Inspect", deadlineMs: 60_000 } as never, undefined, undefined, { ...context(overridden.root), model: { provider: "parent", id: "model" } } as never);
    await vi.waitFor(() => expect(overridden.fake.controllers[0]?.starts).toHaveLength(1));
    expect(overridden.fake.controllers[0].starts[0].options.agent.model).toBe("override/model");
    overridden.fake.controllers[0].settle();
    await overrideRun;
  });

  test("falls back to settings defaults and reports invalid discovery without spawning", async () => {
    const settingsPath = join(temporaryDirectory("settings-"), "settings.json");
    writeFileSync(settingsPath, JSON.stringify({ defaultProvider: "default", defaultModel: "model" }));
    const env = setup({ settingsPath });
    const running = env.invoke({ action: "run", agent: "scout", objective: "Inspect" });
    await vi.waitFor(() => expect(env.fake.controllers[0]?.starts).toHaveLength(1));
    expect(env.fake.controllers[0].starts[0].options.agent.model).toBe("default/model");
    env.fake.controllers[0].settle();
    await running;

    writeAgent(env.agents, "broken");
    writeFileSync(join(env.agents, "broken.md"), "---\nname: broken\ntools: nope\n---\n");
    const invalid = await env.invoke({ action: "run", agent: "broken", objective: "Nope" });
    expect(invalid.isError).toBe(true);
    expect(env.fake.factory).toHaveBeenCalledOnce();
  });
});
