import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, test } from "vitest";

import { loadSettingsDefaults, loadSubagentOverrides, loadSubagentSettings } from "../agents.ts";

function tempSettings(content: string | undefined): string {
  const dir = mkdtempSync(join(tmpdir(), "pi-settings-"));
  const path = join(dir, "settings.json");
  if (content !== undefined) writeFileSync(path, content);
  else rmSync(path, { force: true });
  return path;
}

describe("settings单读", () => {
  test("缺失文件返回空而不报错", () => {
    const path = tempSettings(undefined);
    const combined = loadSubagentSettings(path);
    expect(combined.errors).toEqual([]);
    expect(combined.defaults).toEqual({});
    expect(combined.overrides).toBeUndefined();
    expect(loadSubagentOverrides(path).errors).toEqual([]);
    expect(loadSettingsDefaults(path)).toEqual({});
  });

  test("非法JSON与非法subagent形态收敛为同错误", () => {
    const badJson = tempSettings("{oops");
    expect(loadSubagentSettings(badJson).errors).toHaveLength(1);
    expect(loadSubagentOverrides(badJson).errors).toHaveLength(1);
    const badShape = tempSettings(JSON.stringify({ subagent: 42 }));
    const combined = loadSubagentSettings(badShape);
    expect(combined.errors.some((e) => e.filePath === "settings.json:subagent")).toBe(true);
    expect(loadSubagentOverrides(badShape).errors).toEqual(combined.errors);
  });

  test("非法capacity与合法defaults一次读取同时产出", () => {
    const path = tempSettings(JSON.stringify({
      defaultProvider: "openai",
      defaultModel: "gpt-5",
      subagent: { maxConcurrentRuns: 99, subagents: { scout: { model: "openai/gpt-5" } } },
    }));
    const combined = loadSubagentSettings(path);
    expect(combined.maxConcurrentRuns).toBeUndefined();
    expect(combined.errors.some((e) => e.filePath === "settings.json:subagent.maxConcurrentRuns")).toBe(true);
    expect(combined.defaults).toEqual({ defaultProvider: "openai", defaultModel: "gpt-5" });
    expect(combined.overrides).toEqual({ scout: { model: "openai/gpt-5" } });
  });
});
