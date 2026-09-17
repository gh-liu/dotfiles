import { describe, expect, test, vi } from "vitest";
import { setup } from "./harness.ts";

describe("Feature: output is safe and bounded", () => {
  test("Scenario: secrets and internal identities never reach the parent model", async () => {
    const env = setup({ credentialValues: ["secret", "secret-long-value"] });
    const delegated = env.execute({ task: "inspect" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));
    env.children[0].complete([
      "token=secret-long-value",
      "sessionPath=/tmp/private/session.jsonl",
      "processId=12345 operationId=operation-7 runId=run-8",
      "tokenCount=3 passwordless=true",
    ].join("\n"));

    const text = (await delegated).content[0].text;
    expect(text).not.toContain("secret-long-value");
    expect(text).not.toContain("/tmp/private/session.jsonl");
    expect(text).not.toContain("operation-7");
    expect(text).not.toContain("run-8");
    expect(text).toContain("tokenCount=3 passwordless=true");
  });

  test("Scenario: oversized output has deterministic line and character bounds", async () => {
    const env = setup();
    const delegated = env.execute({ task: "large" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));
    env.children[0].complete(Array.from({ length: 600 }, (_, index) => `line-${index}-${"x".repeat(80)}`).join("\n"));

    const parsed = JSON.parse((await delegated).content[0].text) as { handoff: string };
    expect(parsed.handoff.length).toBeLessThanOrEqual(16_000);
    expect(parsed.handoff.split("\n").length).toBeLessThanOrEqual(400);
    expect(parsed.handoff.startsWith("line-0-")).toBe(true);
    expect(parsed.handoff).toContain("[truncated]");
  });

  test("Scenario: plain final text is valid", async () => {
    const env = setup();
    const delegated = env.execute({ task: "plain prose" });
    await vi.waitFor(() => expect(env.children).toHaveLength(1));
    env.children[0].complete("The ownership boundary is the repository adapter.");

    expect(JSON.parse((await delegated).content[0].text).handoff)
      .toBe("The ownership boundary is the repository adapter.");
  });
});
