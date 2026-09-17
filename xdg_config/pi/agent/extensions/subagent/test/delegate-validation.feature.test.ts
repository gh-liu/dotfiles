import { describe, expect, test } from "vitest";
import { setup } from "./harness.ts";

describe("Feature: reject invalid work before side effects", () => {
  test("Scenario: the public schema exposes task plus optional model/thinking options", () => {
    const env = setup();
    const schema = JSON.parse(JSON.stringify(env.tool.parameters)) as {
      additionalProperties?: boolean;
      properties: Record<string, { additionalProperties?: boolean; properties?: Record<string, unknown> }>;
      required: string[];
    };

    expect(Object.keys(schema.properties)).toEqual(["task", "opts"]);
    expect(schema.required).toEqual(["task"]);
    expect(schema.additionalProperties).toBe(false);
    expect(Object.keys(schema.properties.opts.properties ?? {})).toEqual(["model", "thinking"]);
    expect(schema.properties.opts.additionalProperties).toBe(false);
  });

  test.each([
    [{}, "task is required"],
    [{ task: "" }, "task must not be empty"],
    [{ task: "   \n" }, "task must not be empty"],
    [{ task: "work", opts: "bad" }, "opts must be an object"],
    [{ task: "work", opts: { thinking: "extreme" } }, "unsupported thinking level"],
    [{ task: "work", opts: { model: "missing/model" } }, "unknown model"],
    [{ task: "work", role: "reviewer" }, "unsupported field"],
  ])("Scenario Outline: invalid input %# does not start a child", async (params, error) => {
    const env = setup();
    const result = await env.execute(params);

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain(error);
    expect(env.children).toHaveLength(0);
  });
});
