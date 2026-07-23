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
    const { exp } = JSON.parse(
      Buffer.from(access.split(".")[1] ?? "", "base64url").toString("utf8"),
    );

    if (
      typeof access !== "string" ||
      typeof refresh !== "string" ||
      typeof accountId !== "string" ||
      typeof exp !== "number"
    ) {
      return [{}, false];
    }
    return [{ type: "oauth", access, refresh, accountId, expires: exp * 1000 }, true];
  } catch {
    return [{}, false];
  }
}
