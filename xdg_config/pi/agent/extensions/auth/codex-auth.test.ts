import { describe, expect, test } from "vitest";
import { createHash } from "node:crypto";
import { codexAuth, codexKeychainAccount } from "./codex-auth.ts";

const token = (exp = 2_000_000_000) => `header.${Buffer.from(JSON.stringify({ exp })).toString("base64url")}.signature`;
const auth = (access = token()) => JSON.stringify({ tokens: { access_token: access, refresh_token: "refresh", account_id: "account" } });

describe("codex auth", () => {
  test("uses the macOS keychain before the file", async () => {
    let fileRead = false;
    const result = await codexAuth({ platform: "darwin", home: "/home/test", env: { CODEX_HOME: "/tmp/codex" },
      execSecurity: async () => auth(), readFile: async () => { fileRead = true; return auth(); } });
    expect(result[1]).toBe(true);
    expect(fileRead).toBe(false);
    expect(result[0]).toMatchObject({ type: "oauth", accountId: "account" });
  });

  test("falls back when keychain fails or contains an API key", async () => {
    const result = await codexAuth({ platform: "darwin", home: "/home/test", env: { CODEX_HOME: "/tmp/codex" },
      execSecurity: async () => JSON.stringify({ api_key: "secret" }), readFile: async () => auth() });
    expect(result[1]).toBe(true);
    expect(result[0]).not.toHaveProperty("api_key");
  });

  test("reads the configured CODEX_HOME file and rejects bad fields or JWT", async () => {
    expect((await codexAuth({ platform: "linux", env: { CODEX_HOME: "/configured" }, readFile: async () => auth("not-a-jwt") }))[1]).toBe(false);
    expect((await codexAuth({ platform: "linux", env: { CODEX_HOME: "/configured" }, readFile: async () => JSON.stringify({ tokens: { access_token: token() } }) }))[1]).toBe(false);
  });

  test("uses the documented account hash of canonical CODEX_HOME", async () => {
    const path = "/tmp/codex-home";
    const expected = createHash("sha256").update(path).digest("hex").slice(0, 16);
    expect(await codexKeychainAccount(path)).toBe(`cli|${expected}`);
  });

  test("falls back on keychain rejections and uses the configured file path", async () => {
    let filePath = "";
    const result = await codexAuth({ platform: "darwin", env: { CODEX_HOME: "/configured/codex" },
      execSecurity: async () => { throw new Error("synthetic-secret"); },
      readFile: async (path) => { filePath = path; return auth(); } });
    expect(result[1]).toBe(true);
    expect(filePath).toBe("/configured/codex/auth.json");
  });

  test.each([0, -1, 1e308])("rejects invalid or overflowing expiry %s", async (exp) => {
    expect(await codexAuth({ platform: "linux", env: {}, readFile: async () => auth(token(exp)) })).toEqual([{}, false]);
  });

  test.each(["access_token", "refresh_token", "account_id"])("rejects empty %s", async (field) => {
    const tokens = { access_token: token(), refresh_token: "refresh", account_id: "account", [field]: " " };
    expect(await codexAuth({ platform: "linux", env: {}, readFile: async () => JSON.stringify({ tokens }) })).toEqual([{}, false]);
  });

  test("does not expose secrets in unavailable results", async () => {
    const result = await codexAuth({ platform: "linux", env: { CODEX_HOME: "/missing" }, readFile: async () => { throw new Error("secret-token"); } });
    expect(result).toEqual([{}, false]);
    expect(JSON.stringify(result)).not.toContain("secret-token");
  });
});
