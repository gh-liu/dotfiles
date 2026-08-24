import { describe, expect, test } from "vitest";

import {
  analyzeMessages,
  attributeSystemPrompt,
  basename,
  classifyActiveTools,
  estimateTokens,
  getBarSegments,
  getCompactionReserveTokens,
  safeStringify,
  scaleTokenGroups,
} from "./analysis.ts";

describe("context analysis", () => {
  test("uses Pi's default compaction reserve and clamps tiny windows", () => {
    expect(getCompactionReserveTokens(200_000)).toBe(16_384);
    expect(getCompactionReserveTokens(8_000)).toBe(8_000);
  });

  test("keeps low usage visible and bar segments within the available width", () => {
    expect(getBarSegments(2_000, 1_000_000, 16_384, 60)).toEqual({ used: 1, free: 58, reserve: 1 });
    expect(getBarSegments(50_000, 100_000, 16_384, 20)).toEqual({ used: 10, free: 7, reserve: 3 });
    expect(getBarSegments(120_000, 100_000, 16_384, 20)).toEqual({ used: 20, free: 0, reserve: 0 });
  });

  test("classifies only active tools without trusting extension names over builtin ownership", () => {
    const result = classifyActiveTools([
      { name: "read", sourceInfo: { source: "extension", path: "/custom/read.ts" } },
      { name: "subagent", sourceInfo: { source: "extension", path: "/custom/subagent.ts" } },
      { name: "hidden", sourceInfo: { source: "extension", path: "/custom/hidden.ts" } },
      { name: "native", sourceInfo: { source: "package", path: "/node_modules/pi-coding-agent/native.ts" } },
    ], ["read", "subagent", "native"]);
    expect(result.systemTools.map((tool) => tool.name)).toEqual(["read", "native"]);
    expect(result.extensionTools.map((tool) => tool.name)).toEqual(["subagent"]);
  });

  test("counts compaction-aware message forms including thinking, tool calls, bash output, and custom messages", () => {
    const breakdown = analyzeMessages([
      { role: "user", content: [{ type: "text", text: "question" }] },
      { role: "assistant", content: [
        { type: "thinking", thinking: "reasoning", thinkingSignature: "signature" },
        { type: "toolCall", name: "read", arguments: { path: "large-file.ts" } },
      ] },
      { role: "toolResult", toolName: "read", content: [{ type: "text", text: "result text" }] },
      { role: "bashExecution", command: "npm test", output: "all tests passed" },
      { role: "custom", content: "extension context" },
      { role: "compactionSummary", summary: "older conversation" },
    ]);
    expect(breakdown.total).toBeGreaterThan(0);
    expect(breakdown.byRole.user).toBeGreaterThan(0);
    expect(breakdown.byRole.assistant).toBeGreaterThan(breakdown.byRole.user);
    expect(breakdown.byRole.toolResult).toBeGreaterThan(0);
    expect(breakdown.byRole.bashExecution).toBeGreaterThan(0);
    expect(breakdown.byRole.other).toBeGreaterThan(0);
  });

  test("attributes only context files and visible skills actually embedded in the prompt", () => {
    const prompt = "base prompt\n/path/AGENTS.md\nproject rules\n/path/skill/SKILL.md\nSkill description";
    const result = attributeSystemPrompt(prompt, [
      { path: "/path/AGENTS.md", content: "project rules" },
      { path: "/missing.md", content: "not embedded" },
    ], [
      { name: "skill", description: "Skill description", filePath: "/path/skill/SKILL.md" },
      { name: "hidden", filePath: "/hidden/SKILL.md", disableModelInvocation: true },
    ]);
    expect(result.memoryFilesRaw).toBeGreaterThan(0);
    expect(result.skillsRaw).toBeGreaterThan(0);
    expect(result.systemPromptRaw + result.memoryFilesRaw + result.skillsRaw).toBe(estimateTokens(prompt));
  });

  test("handles circular tool schemas and scales categories to the exact authoritative total", () => {
    const circular: Record<string, unknown> = {};
    circular.self = circular;
    expect(safeStringify(circular)).toContain("[Circular]");
    const scaled = scaleTokenGroups({ system: 3, tools: 2, messages: 1 }, 101);
    expect(Object.values(scaled).reduce((sum, value) => sum + value, 0)).toBe(101);
    expect(scaled.system).toBeGreaterThan(scaled.tools);
    expect(scaleTokenGroups({ system: 0, messages: 0 }, 17)).toEqual({ system: 17, messages: 0 });
  });

  test("extracts POSIX and Windows basenames", () => {
    expect(basename("/repo/AGENTS.md")).toBe("AGENTS.md");
    expect(basename("C:\\repo\\AGENTS.md")).toBe("AGENTS.md");
  });
});
