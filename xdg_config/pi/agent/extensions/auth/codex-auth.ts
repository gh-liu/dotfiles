import { readFile, realpath } from "node:fs/promises";
import { homedir } from "node:os";
import { execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { isAbsolute, join, resolve } from "node:path";

import type { OAuthCredential } from "@earendil-works/pi-ai";

type AuthResult = [credential: OAuthCredential, available: true] | [credential: Record<string, never>, available: false];

type ReaderOptions = {
  env?: NodeJS.ProcessEnv;
  platform?: NodeJS.Platform;
  home?: string;
  readFile?: (path: string, encoding: "utf8") => string | Promise<string>;
  execSecurity?: (args: string[]) => string | Promise<string>;
};

function execSecurityDefault(args: string[]): Promise<string> {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = execFile("security", args, { encoding: "utf8", timeout: 2000 }, (error, stdout) => {
      if (error) rejectPromise(error);
      else resolvePromise(stdout);
    });
    child.stdin?.end();
  });
}

export async function codexKeychainAccount(codexHome: string): Promise<string> {
  const canonical = await realpath(codexHome).catch(() => resolve(codexHome));
  return `cli|${createHash("sha256").update(canonical).digest("hex").slice(0, 16)}`;
}

function oauthCredential(source: unknown): AuthResult {
  if (!source || typeof source !== "object") return [{}, false];
  const record = source as Record<string, unknown>;
  const tokens = record.tokens && typeof record.tokens === "object" ? record.tokens as Record<string, unknown> : record;
  const access = tokens.access_token;
  const refresh = tokens.refresh_token;
  const accountId = tokens.account_id;
  if (typeof access !== "string" || !access.trim() || typeof refresh !== "string" || !refresh.trim() || typeof accountId !== "string" || !accountId.trim()) return [{}, false];
  try {
    const payload = JSON.parse(Buffer.from(access.split(".")[1] ?? "", "base64url").toString("utf8")) as { exp?: unknown };
    if (typeof payload.exp !== "number" || payload.exp <= 0 || !Number.isFinite(payload.exp * 1000)) return [{}, false];
    return [{ type: "oauth", access, refresh, accountId, expires: payload.exp * 1000 }, true];
  } catch { return [{}, false]; }
}

function keychainPayload(raw: string): unknown {
  try { return JSON.parse(raw); } catch { return undefined; }
}

export async function codexAuth(options: ReaderOptions = {}): Promise<AuthResult> {
  const env = options.env ?? process.env;
  const home = options.home ?? homedir();
  const codexHomeValue = env.CODEX_HOME || join(home, ".codex");
  const codexHome = isAbsolute(codexHomeValue) ? codexHomeValue : resolve(codexHomeValue);
  const read = options.readFile ?? ((path: string, encoding: "utf8") => readFile(path, encoding));
  if ((options.platform ?? process.platform) === "darwin") {
    try {
      const exec = options.execSecurity ?? execSecurityDefault;
      const raw = await exec(["find-internet-password", "-s", "Codex Auth", "-a", await codexKeychainAccount(codexHome), "-w"]);
      const result = oauthCredential(keychainPayload(raw));
      if (result[1]) return result;
    } catch { /* fall through to the file */ }
  }
  try { return oauthCredential(JSON.parse(await read(join(codexHome, "auth.json"), "utf8"))); } catch { return [{}, false]; }
}
