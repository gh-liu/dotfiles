import type { AuthStorage } from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

import { CODEX_PROVIDER } from "./codex-usage.ts";

const CODEX_CLI_AUTH_PATH = join(homedir(), ".codex", "auth.json");
const CODEX_ACCESS_TOKEN_TTL_MS = 50 * 60 * 1000;

interface CodexCliAuthFile {
  tokens?: {
    access_token?: unknown;
    refresh_token?: unknown;
    account_id?: unknown;
  };
  last_refresh?: unknown;
}

function readString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function resolveCodexCliTokenExpiry(lastRefresh: unknown): number {
  const lastRefreshMs = typeof lastRefresh === "string" ? Date.parse(lastRefresh) : NaN;
  return (Number.isFinite(lastRefreshMs) ? lastRefreshMs : Date.now()) + CODEX_ACCESS_TOKEN_TTL_MS;
}

export function syncCodexAuthFromCodexCli(authStorage: AuthStorage): boolean {
  if (!existsSync(CODEX_CLI_AUTH_PATH)) {
    return false;
  }

  let auth: CodexCliAuthFile;
  try {
    auth = JSON.parse(readFileSync(CODEX_CLI_AUTH_PATH, "utf8")) as CodexCliAuthFile;
  } catch {
    return false;
  }

  const access = readString(auth.tokens?.access_token);
  const refresh = readString(auth.tokens?.refresh_token);
  const accountId = readString(auth.tokens?.account_id);
  if (!access || !refresh || !accountId) {
    return false;
  }

  authStorage.set(CODEX_PROVIDER, {
    type: "oauth",
    access,
    refresh,
    accountId,
    expires: resolveCodexCliTokenExpiry(auth.last_refresh),
  });

  return true;
}
