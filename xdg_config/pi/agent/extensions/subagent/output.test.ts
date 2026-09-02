import { describe, expect, test } from "vitest";

import { boundText, redactSecrets, serializeSubagentResult } from "./output.ts";

describe("bounded output", () => {
  test("bounds lines and characters and redacts likely secrets", () => {
    const text = [
      "OPENAI_API_KEY=super-secret-value",
      "Authorization: Bearer abc.def.ghi",
      'credentials={"token":"json-secret-value"}',
      "api_key=lowercase-secret-value",
      "provider key: [REDACTED:sk-secret]",
      "third line",
      "fourth line",
    ].join("\n");

    const bounded = boundText(text, { maxCharacters: 300, maxLines: 8 });

    expect(bounded).not.toContain("super-secret-value");
    expect(bounded).not.toContain("abc.def.ghi");
    expect(bounded).not.toContain("json-secret-value");
    expect(bounded).not.toContain("lowercase-secret-value");
    expect(bounded).not.toContain("[REDACTED:sk-secret]");
    expect(bounded).toContain("[REDACTED]");
  });

  test("redacts exact values idempotently without corrupting benign keys", () => {
    const shortSecret = "tiny";
    const spacedSecret = "alpha beta";
    const text = [
      `token=${spacedSecret}`,
      `password=${shortSecret}`,
      "tokenCount=3",
      "passwordless=true",
      "notasecret=public",
      "token=[REDACTED]",
    ].join("\n");

    const redacted = redactSecrets(text, [shortSecret, spacedSecret, "alpha"]);

    expect(redacted).not.toContain(shortSecret);
    expect(redacted).not.toContain(spacedSecret);
    expect(redacted).toContain("tokenCount=3");
    expect(redacted).toContain("passwordless=true");
    expect(redacted).toContain("notasecret=public");
    expect(redacted).not.toContain("[[REDACTED]]");
    expect(redactSecrets(redacted, [shortSecret, spacedSecret, "REDACTED"])).toBe(redacted);
  });

  test("bounds oversized structured sections as one envelope", () => {
    const large = "x".repeat(20_000);
    const serialized = serializeSubagentResult({
      runId: "job", operationId: "private", agent: "scout", status: "completed",
      summary: `## Summary\n${large}\n## Changes\n${large}\n## Evidence\n${large}\n## Validation\n${large}\n## Risks\n${large}`,
      transcript: {},
    });
    expect(serialized.length).toBeLessThanOrEqual(16_000);
    expect(JSON.parse(serialized)).toMatchObject({ changes: expect.any(String), evidence: expect.any(String), validation: expect.any(String), risks: expect.any(String) });
  });

  test("fairly converges with several huge escaped sections", () => {
    const huge = "\\\"\n".repeat(20_000);
    const serialized = serializeSubagentResult({
      runId: "job", operationId: "private", agent: "scout", status: "completed",
      summary: `# Summary\n${huge}\n# Changes\n${huge}\n# Evidence\n${huge}`,
      transcript: { sessionPath: "/sessions/result.jsonl" },
    });
    expect(serialized.length).toBeLessThanOrEqual(16_000);
  });
});
