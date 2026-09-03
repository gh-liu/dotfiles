import { describe, expect, test } from "vitest";

import { collectCredentialValues, redactSecrets, sanitizeOneLine } from "../output.ts";
import { oneLine } from "../render/shared.ts";

describe("统一sanitizer五出口", () => {
  test("最长优先: 长哨兵覆盖短哨兵不残留", () => {
    const long = "sk-long-secret-value-12345";
    const short = "secret";
    const text = `token=${long} and ${short}`;
    const redacted = redactSecrets(text, [short, long]);
    expect(redacted).not.toContain(long);
    expect(redacted).not.toContain("sk-long-secret-value-12345");
    expect(redactSecrets(redacted, [short, long])).toBe(redacted);
  });

  test("sanitizeOneLine: 精确值+通用模式脱敏并单行截断幂等", () => {
    const secret = "my-exact-credential-abc";
    const text = `  api_key=${secret}  Authorization: Bearer xyz.123\nnext line  `;
    const once = sanitizeOneLine(text, 60, [secret]);
    expect(once).not.toContain(secret);
    expect(once).not.toContain("xyz.123");
    expect(once).not.toContain("\n");
    expect(once.length).toBeLessThanOrEqual(60);
    expect(sanitizeOneLine(once, 60, [secret])).toBe(once);
  });

  test("render共享oneLine同样脱敏通用模式", () => {
    const line = oneLine("api_key=lowercase-secret-value and more", 160);
    expect(line).not.toContain("lowercase-secret-value");
    expect(line).toContain("[REDACTED]");
  });

  test("collectCredentialValues最长优先去重", () => {
    const env = { A: "short", B: "much-longer-value", C: "", D: "short" } as Record<string, string>;
    expect(collectCredentialValues(["A", "B", "C", "MISSING", "A"], env)).toEqual(["much-longer-value", "short"]);
  });

  test("sdk/live/通知共用: 带哨兵的tool摘要经sanitize后无残留", () => {
    const secret = "sdk-secret-999";
    const summary = sanitizeOneLine(`bash ${secret} --flag`, 120, [secret]);
    expect(summary).not.toContain(secret);
    expect(summary.startsWith("bash")).toBe(true);
  });
});
