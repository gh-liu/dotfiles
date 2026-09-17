import { mkdirSync, symlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, test, vi } from "vitest";
import { setup, temporaryDirectory } from "./harness.ts";

describe("Feature: execution options and context resolution", () => {
  test.each([
    [undefined, "parent-provider/parent-model", "medium"],
    [{ model: "child-provider/child-model" }, "child-provider/child-model", "medium"],
    [{ thinking: "low" }, "parent-provider/parent-model", "low"],
    [{ model: "child-provider/child-model", thinking: "high" }, "child-provider/child-model", "high"],
  ])("Scenario Outline: opts %# override only named values", async (opts, model, thinking) => {
    const env = setup();
    const delegated = env.execute({ task: "inspect", ...(opts ? { opts } : {}) });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));

    expect(`${env.children[0].request.model.provider}/${env.children[0].request.model.id}`).toBe(model);
    expect(env.children[0].request.thinking).toBe(thinking);
    env.children[0].complete();
    await delegated;
  });

  test("Scenario: guidance is ordered, applicable, and bounded", async () => {
    const root = temporaryDirectory();
    const nested = join(root, "src", "feature");
    mkdirSync(nested, { recursive: true });
    writeFileSync(join(root, "AGENTS.md"), `ROOT_RULE\n${"root\n".repeat(500)}`);
    writeFileSync(join(root, "src", "AGENTS.md"), `SOURCE_RULE\n${"source\n".repeat(500)}`);
    writeFileSync(join(nested, "AGENTS.md"), `FEATURE_RULE\n${"feature\n".repeat(500)}`);
    const env = setup({ cwd: nested });

    const delegated = env.execute({ task: "inspect" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));
    const guidance = env.children[0].request.guidance.join("\n");
    expect(guidance.indexOf("ROOT_RULE")).toBeLessThan(guidance.indexOf("SOURCE_RULE"));
    expect(guidance.indexOf("SOURCE_RULE")).toBeLessThan(guidance.indexOf("FEATURE_RULE"));
    expect(guidance.length).toBeLessThanOrEqual(32_000);
    expect(guidance).toContain("[truncated]");
    env.children[0].complete();
    await delegated;
  });

  test("Scenario: a canonical cwd cannot escape the allowed project root", async () => {
    const root = temporaryDirectory();
    const outside = temporaryDirectory();
    symlinkSync(outside, join(root, "escape"));
    const env = setup({ cwd: root });

    const result = await env.execute({ task: "inspect" }, undefined, { cwd: join(root, "escape") });
    expect(result.isError).toBe(true);
    expect(env.children).toHaveLength(0);
  });
});
