import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export function codexAuth(): [Record<string, unknown>, boolean] {
  try {
    const source = JSON.parse(readFileSync(join(homedir(), ".codex", "auth.json"), "utf8"));
    const {
      access_token: access,
      refresh_token: refresh,
      account_id: accountId,
    } = source.tokens ?? {};

    if (
      typeof access !== "string" ||
      typeof refresh !== "string" ||
      typeof accountId !== "string"
    ) {
      return [{}, false];
    }
    return [{ type: "oauth", access, refresh, accountId }, true];
  } catch {
    return [{}, false];
  }
}
