import { describe, expect, test } from "vitest";

import { boundText, redactSecrets } from "./output.ts";

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
});
