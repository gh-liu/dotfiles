import { afterEach, describe, expect, test } from "vitest";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  applyAgentOverrides,
  discoverUserAgents,
  loadAgentDefinition,
  loadSettingsDefaults,
  parseAgentDefinition,
  resolveAgentModel,
  type AgentDefinition,
  type SettingsDefaults,
} from "./agents.ts";

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function temporaryAgentDir(): string {
  const directory = mkdtempSync(join(tmpdir(), "pi-subagent-agents-"));
  temporaryDirectories.push(directory);
  return directory;
}

describe("settings defaults", () => {
  test("loads the default provider/model that child sessions resolve", () => {
    const dir = temporaryAgentDir();
    const settingsPath = join(dir, "settings.json");
    writeFileSync(settingsPath, JSON.stringify({
      defaultProvider: "opencode-go",
      defaultModel: "deepseek-v4-flash",
      subagent: { subagents: {} },
    }));

    expect(loadSettingsDefaults(settingsPath)).toEqual({
      defaultProvider: "opencode-go",
      defaultModel: "deepseek-v4-flash",
    });
  });

  test("returns empty defaults when provider/model are absent", () => {
    const dir = temporaryAgentDir();
    const settingsPath = join(dir, "settings.json");
    writeFileSync(settingsPath, JSON.stringify({ theme: "nord" }));
    expect(loadSettingsDefaults(settingsPath)).toEqual({});
  });

  test("returns empty defaults when the settings file is missing", () => {
    const dir = temporaryAgentDir();
    expect(loadSettingsDefaults(join(dir, "missing.json"))).toEqual({});
  });

  test("returns empty defaults on malformed settings JSON", () => {
    const dir = temporaryAgentDir();
    const settingsPath = join(dir, "settings.json");
    writeFileSync(settingsPath, "{ not json");
    expect(loadSettingsDefaults(settingsPath)).toEqual({});
  });
});

describe("model resolution", () => {
  const plainAgent: AgentDefinition = {
    name: "scout",
    description: "Inspect files",
    systemPrompt: "Inspect the repository.",
    tools: ["read"],
    contextPolicy: "fresh",
    maxDepth: 1,
    filePath: "/agents/scout.md",
  };
  const explicitAgent: AgentDefinition = {
    ...plainAgent,
    model: "openai-codex/gpt-5.6-sol",
  };
  const defaults: SettingsDefaults = {
    defaultProvider: "opencode-go",
    defaultModel: "deepseek-v4-flash",
  };

  test("an explicit model wins over the main model and settings defaults", () => {
    expect(resolveAgentModel(explicitAgent, defaults, "opencode-go/deepseek-v4")).toBe("openai-codex/gpt-5.6-sol");
  });

  test("the main model wins over settings defaults when the agent has no explicit model", () => {
    expect(resolveAgentModel(plainAgent, defaults, "opencode-go/deepseek-v4")).toBe("opencode-go/deepseek-v4");
  });

  test("falls back to the canonical settings default when no explicit or main model exists", () => {
    expect(resolveAgentModel(plainAgent, defaults)).toBe("opencode-go/deepseek-v4-flash");
  });

  test("returns undefined when explicit, main, and defaults are all absent", () => {
    expect(resolveAgentModel(plainAgent, {})).toBeUndefined();
    expect(resolveAgentModel(plainAgent, { defaultProvider: "opencode-go" })).toBeUndefined();
    expect(resolveAgentModel(plainAgent, { defaultModel: "deepseek-v4-flash" })).toBeUndefined();
  });
});

describe("agent definitions", () => {
  test("loads the bundled scout as a minimal-thinking read-only profile", () => {
    const scout = loadAgentDefinition(
      fileURLToPath(new URL("../../agents/scout.md", import.meta.url)),
    );

    expect(scout).toMatchObject({
      name: "scout",
      thinking: "minimal",
      tools: ["read", "grep", "find", "ls", "web_search"],
      contextPolicy: "fresh",
      maxDepth: 1,
    });
    expect(scout.systemPrompt).toContain("# Code Context");
    expect(scout.systemPrompt).toContain("## Parent Next Step");
    expect(scout.systemPrompt).toContain("Do not return a flat list of keyword matches");
    expect(scout.systemPrompt).toContain("For web research");
    expect(scout.description).toContain("local and web investigation");
  });

  test("loads the bundled reviewer as a medium-thinking read-only review profile", () => {
    const reviewer = loadAgentDefinition(
      fileURLToPath(new URL("../../agents/reviewer.md", import.meta.url)),
    );

    expect(reviewer).toMatchObject({
      name: "reviewer",
      thinking: "medium",
      tools: ["read", "grep", "find", "ls"],
      contextPolicy: "fresh",
      maxDepth: 1,
    });
    expect(reviewer.systemPrompt).toContain("# Review: [pass | findings | blocked]");
    expect(reviewer.systemPrompt).toContain("Review intent first and implementation second");
    expect(reviewer.systemPrompt).toContain("severity");
    expect(reviewer.systemPrompt).toContain("Do not modify files");
    expect(reviewer.systemPrompt).toContain("Judgment");
    expect(reviewer.systemPrompt).toContain("recommendation or verdict");
    expect(reviewer.description).toContain("review and expert judgment");
  });

  test("loads the bundled worker as a medium-thinking implementation profile", () => {
    const worker = loadAgentDefinition(
      fileURLToPath(new URL("../../agents/worker.md", import.meta.url)),
    );

    expect(worker).toMatchObject({
      name: "worker",
      thinking: "medium",
      tools: ["read", "grep", "find", "ls", "edit", "write", "bash"],
      contextPolicy: "fresh",
      maxDepth: 1,
    });
    expect(worker.systemPrompt).toContain("# Status: [complete | partial | blocked]");
    expect(worker.systemPrompt).toContain("settled outcome");
    expect(worker.systemPrompt).toContain("Do not assume every line in the final diff is yours");
    expect(worker.description).toContain("not discovery or architecture design");
  });

  test("loads the bundled tester with fail-fast provisioning and explicit isolation limits", () => {
    const tester = loadAgentDefinition(
      fileURLToPath(new URL("../../agents/tester.md", import.meta.url)),
    );

    expect(tester).toMatchObject({
      name: "tester",
      thinking: "medium",
      tools: ["read", "grep", "find", "ls", "bash"],
      contextPolicy: "fresh",
      maxDepth: 1,
    });
    expect(tester.description).toContain("Fresh-context exploratory QA");
    expect(tester.description).toContain("use instead of parent-driven browser testing");
    expect(tester.systemPrompt).toContain("not a filesystem, process, network, or credential sandbox");
    expect(tester.systemPrompt).toContain("report the missing prerequisite as a blocker");
    expect(tester.systemPrompt).toContain("Never install packages, browsers, or system dependencies");
    expect(tester.systemPrompt).toContain("never run it as a blocking foreground shell call");
    expect(tester.systemPrompt).toContain("record the actual service PID rather than a wrapper-shell PID");
    expect(tester.systemPrompt).toContain("verify the PID no longer exists");
    expect(tester.systemPrompt).toContain("Do not create a patched copy, substitute server");
    expect(tester.systemPrompt).not.toContain("npm i -g");
  });

  test("keeps bundled routing descriptions concise and distinct", () => {
    const agents = discoverUserAgents(fileURLToPath(new URL("../../agents", import.meta.url))).agents;

    expect(agents).toHaveLength(4);
    expect(new Set(agents.map((agent) => agent.description)).size).toBe(4);
    for (const agent of agents) {
      expect(agent.description.length, `${agent.name} description`).toBeLessThanOrEqual(160);
    }
  });

  test("parses a read-only user agent", () => {
    const definition = parseAgentDefinition(
      `---
name: scout
description: Inspect a codebase without modifying it
tools:
  - read
  - grep
  - find
  - ls
model: openai/gpt-5-mini
thinking: low
---
Return concise findings with file and line evidence.
`,
    );

    expect(definition).toMatchObject({
      name: "scout",
      description: "Inspect a codebase without modifying it",
      tools: ["read", "grep", "find", "ls"],
      model: "openai/gpt-5-mini",
      thinking: "low",
      contextPolicy: "fresh",
      maxDepth: 1,
      systemPrompt: "Return concise findings with file and line evidence.",
    });
    expect(definition).not.toHaveProperty("filePath");
  });

  test.each([
    ["missing tools", "thinking: low"],
    ["unknown capability", "tools: [read, custom_tool]"],
    ["model fallback", "tools: [read]\nfallbackModels: [openai/gpt-5-mini]"],
    ["executable extensions", "tools: [read]\nextensions: [unsafe.ts]"],
    ["non-fresh context", "tools: [read]\ncontextPolicy: fork"],
    ["nested delegation depth", "tools: [read]\nmaxDepth: 2"],
  ])("rejects unsupported %s", (_label, fields) => {
    expect(() =>
      parseAgentDefinition(
        `---
name: scout
description: Inspect files
${fields}
---
Inspect the repository.
`,
      ),
    ).toThrow();
  });

  test("applies settings overrides for model thinking and description", () => {
    const discovery = {
      agents: [{
        name: "scout",
        description: "File description",
        systemPrompt: "Prompt",
        tools: ["read"],
        contextPolicy: "fresh" as const,
        maxDepth: 1 as const,
        filePath: "/agents/scout.md",
      }],
      errors: [],
    };

    const overridden = applyAgentOverrides(discovery, {
      scout: { model: "openai/gpt-5-mini", thinking: "high", description: "Settings description" },
    });

    expect(overridden.agents[0]).toMatchObject({
      name: "scout",
      model: "openai/gpt-5-mini",
      thinking: "high",
      description: "Settings description",
    });
    expect(overridden.errors).toEqual([]);
    expect(discovery.agents[0]).not.toHaveProperty("model");
  });

  test("applies configured model overrides while preserving role-specific thinking", () => {
    const discovery = discoverUserAgents(fileURLToPath(new URL("../../agents", import.meta.url)));
    const settings = JSON.parse(readFileSync(fileURLToPath(new URL("../../settings.json", import.meta.url)), "utf8")) as {
      subagent: { subagents: Record<string, { model?: string; thinking?: string }> };
    };
    const expectedThinking = {
      worker: "medium",
      scout: "minimal",
      reviewer: "medium",
      tester: "medium",
    };

    const overridden = applyAgentOverrides(discovery, settings.subagent.subagents);

    for (const [name, thinking] of Object.entries(expectedThinking)) {
      expect(settings.subagent.subagents[name]).not.toHaveProperty("thinking");
      expect(overridden.agents.find((agent) => agent.name === name)).toMatchObject({
        ...(settings.subagent.subagents[name].model ? { model: settings.subagent.subagents[name].model } : {}),
        thinking,
      });
    }
  });

  test("applies partial settings overrides without replacing absent fields", () => {
    const overridden = applyAgentOverrides({
      agents: [{
        name: "scout",
        description: "File description",
        systemPrompt: "Prompt",
        model: "file/model",
        thinking: "low",
        tools: ["read"],
        contextPolicy: "fresh" as const,
        maxDepth: 1 as const,
        filePath: "/agents/scout.md",
      }],
      errors: [],
    }, { scout: { thinking: "xhigh" } });

    expect(overridden.agents[0]).toMatchObject({
      description: "File description",
      model: "file/model",
      thinking: "xhigh",
    });
  });

  test("reports unknown settings override names without changing discovered agents", () => {
    const overridden = applyAgentOverrides({
      agents: [{
        name: "scout",
        description: "File description",
        systemPrompt: "Prompt",
        tools: ["read"],
        contextPolicy: "fresh" as const,
        maxDepth: 1 as const,
        filePath: "/agents/scout.md",
      }],
      errors: [],
    }, { missing: { model: "openai/gpt-5" } });

    expect(overridden.agents).toHaveLength(1);
    expect(overridden.agents[0].name).toBe("scout");
    expect(overridden.errors).toEqual([{ filePath: "settings.json:missing", error: "settings.json:missing: unknown agent override: missing" }]);
  });

  test("reports invalid settings override fields while keeping valid agents", () => {
    const overridden = applyAgentOverrides({
      agents: [{
        name: "scout",
        description: "File description",
        systemPrompt: "Prompt",
        tools: ["read"],
        contextPolicy: "fresh" as const,
        maxDepth: 1 as const,
        filePath: "/agents/scout.md",
      }],
      errors: [],
    }, {
      scout: { thinking: "too-much", model: "", description: 3 },
      other: null,
    });

    expect(overridden.agents[0]).toMatchObject({ name: "scout", description: "File description" });
    expect(overridden.agents[0]).not.toHaveProperty("model");
    expect(overridden.agents[0]).not.toHaveProperty("thinking");
    expect(overridden.errors.map((entry) => entry.error)).toEqual([
      "settings.json:scout: model must be a non-empty string",
      "settings.json:scout: unsupported thinking level: too-much",
      "settings.json:scout: description must be a non-empty string",
      "settings.json:other: unknown agent override: other",
    ]);
  });

  test("discovers markdown files deterministically and reports invalid definitions", () => {
    const directory = temporaryAgentDir();
    mkdirSync(join(directory, "nested"));
    writeFileSync(
      join(directory, "zeta.md"),
      "---\nname: zeta\ndescription: Zeta agent\ntools: [read]\n---\nZeta prompt.\n",
    );
    writeFileSync(
      join(directory, "alpha.md"),
      "---\nname: alpha\ndescription: Alpha agent\ntools: [read, grep]\n---\nAlpha prompt.\n",
    );
    writeFileSync(join(directory, "broken.md"), "not frontmatter");
    writeFileSync(join(directory, "ignored.txt"), "ignored");

    const discovery = discoverUserAgents(directory);

    expect(discovery.agents.map((agent) => agent.name)).toEqual(["alpha", "zeta"]);
    expect(discovery.agents.map((agent) => agent.filePath)).toEqual([
      join(directory, "alpha.md"),
      join(directory, "zeta.md"),
    ]);
    expect(discovery.errors).toHaveLength(1);
    expect(discovery.errors[0]).toEqual({
      filePath: join(directory, "broken.md"),
      error: `${join(directory, "broken.md")}: name must be a non-empty string`,
    });
  });

  test("accepts contained definition symlinks and rejects escapes", () => {
    const directory = temporaryAgentDir();
    const outside = temporaryAgentDir();
    const containedTarget = join(directory, "contained.source");
    const escapedTarget = join(outside, "escaped.source");
    writeFileSync(containedTarget, "---\nname: contained\ndescription: Contained\ntools: [read]\n---\nInspect.\n");
    writeFileSync(escapedTarget, "---\nname: escaped\ndescription: Escaped\ntools: [read]\n---\nInspect.\n");
    symlinkSync(containedTarget, join(directory, "contained.md"));
    symlinkSync(escapedTarget, join(directory, "escaped.md"));

    const discovery = discoverUserAgents(directory);

    expect(discovery.agents.map((agent) => agent.name)).toEqual(["contained"]);
    expect(discovery.errors).toEqual([{
      filePath: join(directory, "escaped.md"),
      error: `${join(directory, "escaped.md")}: agent definition symlink resolves outside the agent directory`,
    }]);
  });
});
