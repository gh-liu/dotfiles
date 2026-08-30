import { describe, expect, test } from "vitest";
import { createHash } from "node:crypto";
import { codexAuth, codexKeychainAccount } from "./codex-auth.ts";

const token = (exp = 2_000_000_000) => `header.${Buffer.from(JSON.stringify({ exp })).toString("base64url")}.signature`;
const auth = (access = token()) => JSON.stringify({ tokens: { access_token: access, refresh_token: "refresh", account_id: "account" } });

describe("codex auth", () => {
  test("uses the macOS keychain before the file", () => {
    let fileRead = false;
    const result = codexAuth({ platform: "darwin", home: "/home/test", env: { CODEX_HOME: "/tmp/codex" },
      execSecurity: () => auth(), readFile: () => { fileRead = true; return auth(); } });
    expect(result[1]).toBe(true);
    expect(fileRead).toBe(false);
    expect(result[0]).toMatchObject({ type: "oauth", accountId: "account" });
  });

  test("falls back when keychain fails or contains an API key", () => {
    const result = codexAuth({ platform: "darwin", home: "/home/test", env: { CODEX_HOME: "/tmp/codex" },
      execSecurity: () => JSON.stringify({ api_key: "secret" }), readFile: () => auth() });
    expect(result[1]).toBe(true);
    expect(result[0]).not.toHaveProperty("api_key");
  });

  test("reads the configured CODEX_HOME file and rejects bad fields or JWT", () => {
    expect(codexAuth({ platform: "linux", env: { CODEX_HOME: "/configured" }, readFile: () => auth("not-a-jwt") })[1]).toBe(false);
    expect(codexAuth({ platform: "linux", env: { CODEX_HOME: "/configured" }, readFile: () => JSON.stringify({ tokens: { access_token: token() } }) })[1]).toBe(false);
  });

  test("uses the documented account hash of canonical CODEX_HOME", () => {
    const path = "/tmp/codex-home";
    const expected = createHash("sha256").update(path).digest("hex").slice(0, 16);
    expect(codexKeychainAccount(path)).toBe(`cli|${expected}`);
  });

  test("does not expose secrets in unavailable results", () => {
    const result = codexAuth({ platform: "linux", env: { CODEX_HOME: "/missing" }, readFile: () => { throw new Error("secret-token"); } });
    expect(result).toEqual([{}, false]);
    expect(JSON.stringify(result)).not.toContain("secret-token");
  });
});
