import { describe, expect, test } from "vitest";

import { resolveChildCwd } from "../context.ts";
import { setup, temporaryDirectory } from "./harness.ts";

/**
 * Scope contract: only user-scope agents (`~/.pi/agent/agents`) are supported.
 * Project-local agents are explicitly unsupported, so there is no scope
 * parameter, no project-trust bypass, and no confirm escape hatch.
 */
describe("agent scope contract", () => {
  test("the tool exposes no project scope, confirm, or cwd parameters", () => {
    const env = setup({ ids: ["job", "private"] });
    const schema = JSON.parse(JSON.stringify(env.extension.getTool().parameters)) as {
      properties?: Record<string, unknown>;
    };
    expect(schema.properties).not.toHaveProperty("agentScope");
    expect(schema.properties).not.toHaveProperty("confirmProjectAgents");
    expect(schema.properties).not.toHaveProperty("cwd");
  });

  test("a cwd outside the allowed root is rejected", () => {
    const root = temporaryDirectory("pi-subagent-root-");
    const outside = temporaryDirectory("pi-subagent-outside-");
    expect(() => resolveChildCwd(root, outside)).toThrow("outside the allowed root");
  });

  test("unknown agents resolve against the user catalog only", async () => {
    const env = setup({ ids: ["job", "private"] });
    const result = await env.invoke({ action: "run", agent: "project-only-agent", task: "Do work" });
    expect(result).toMatchObject({ isError: true });
    expect(String((result.details as { error?: unknown }).error)).toMatch(/Unknown agent/);
  });
});
