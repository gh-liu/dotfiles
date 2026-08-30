import { readFileSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { isAbsolute, join, resolve } from "node:path";

type ReaderOptions = {
  env?: NodeJS.ProcessEnv;
  platform?: NodeJS.Platform;
  home?: string;
  readFile?: (path: string, encoding: "utf8") => string;
  execSecurity?: (args: string[]) => string;
};

export function codexKeychainAccount(codexHome: string): string {
  const canonical = (() => {
    try { return realpathSync(codexHome); } catch { return resolve(codexHome); }
  })();
  return `cli|${createHash("sha256").update(canonical).digest("hex").slice(0, 16)}`;
}

function oauthCredential(source: unknown): [Record<string, unknown>, boolean] {
  if (!source || typeof source !== "object") return [{}, false];
  const record = source as Record<string, unknown>;
  const tokens = record.tokens && typeof record.tokens === "object" ? record.tokens as Record<string, unknown> : record;
  const access = tokens.access_token;
  const refresh = tokens.refresh_token;
  const accountId = tokens.account_id;
  if (typeof access !== "string" || typeof refresh !== "string" || typeof accountId !== "string") return [{}, false];
  try {
    const payload = JSON.parse(Buffer.from(access.split(".")[1] ?? "", "base64url").toString("utf8")) as { exp?: unknown };
    if (typeof payload.exp !== "number" || !Number.isFinite(payload.exp)) return [{}, false];
    return [{ type: "oauth", access, refresh, accountId, expires: payload.exp * 1000 }, true];
  } catch { return [{}, false]; }
}

function keychainPayload(raw: string): unknown {
  try { return JSON.parse(raw); } catch { return undefined; }
}

export function codexAuth(options: ReaderOptions = {}): [credential: Record<string, unknown>, available: boolean] {
  const env = options.env ?? process.env;
  const home = options.home ?? homedir();
  const codexHomeValue = env.CODEX_HOME || join(home, ".codex");
  const codexHome = isAbsolute(codexHomeValue) ? codexHomeValue : resolve(codexHomeValue);
  const readFile = options.readFile ?? ((path: string, encoding: "utf8") => readFileSync(path, encoding));
  if ((options.platform ?? process.platform) === "darwin") {
    try {
      const exec = options.execSecurity ?? ((args: string[]) => execFileSync("security", args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }));
      const raw = exec(["find-internet-password", "-s", "Codex Auth", "-a", codexKeychainAccount(codexHome), "-w"]);
      const result = oauthCredential(keychainPayload(raw));
      if (result[1]) return result;
    } catch { /* fall through to the file */ }
  }
  try { return oauthCredential(JSON.parse(readFile(join(codexHome, "auth.json"), "utf8"))); } catch { return [{}, false]; }
}
