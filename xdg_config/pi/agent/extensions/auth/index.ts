// Sync Codex OAuth at session boundaries; Pi still owns request-time refresh.

import type { CredentialStore, OAuthCredential } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import { codexAuth } from "./codex-auth.ts";

function credentialStore(modelRegistry: unknown): Pick<CredentialStore, "modify"> | undefined {
  // Pi 1.0.0 exposes resolved auth, but no credential import/store mutation on
  // ExtensionContext/ModelRegistry. ModelRuntime's public login and runtime API
  // key methods cannot import OAuth. Keep the unavoidable bridge here rather
  // than opening a second auth.json store (which breaks SDK custom stores).
  if (!modelRegistry || typeof modelRegistry !== "object") return undefined;
  const runtime = (modelRegistry as { runtime?: { credentials?: Partial<CredentialStore> } }).runtime;
  const store = runtime?.credentials;
  return typeof store?.modify === "function" ? store as Pick<CredentialStore, "modify"> : undefined;
}

export default function(pi: ExtensionAPI) {
  let inFlight: Promise<void> | undefined;
  let refreshPending = false;

  async function sync(ctx: ExtensionContext): Promise<void> {
    const warn = (message: string) => { if (ctx.hasUI) ctx.ui.notify(message, "warning"); };
    if (!refreshPending) {
      // Read here, not in the factory: resource discovery must not access secrets,
      // and later sessions should see updated Codex credentials.
      const [source, available] = codexAuth();
      if (!available) return;
      const store = credentialStore(ctx.modelRegistry);
      if (!store) {
        warn("Codex credentials could not be synced: this Pi version does not expose the required credential store.");
        return;
      }
      try {
        await store.modify("openai-codex", async (current) => {
          // Decide under Pi's store lock, against the latest credential (including
          // tokens rotated by Pi). Never silently switch accounts or auth methods.
          if (current) {
            if (current.type !== "oauth" || current.accountId !== source.accountId) return undefined;
            if (!Number.isFinite(current.expires) || source.expires <= current.expires) return undefined;
            if (source.expires <= Date.now()) return undefined;
          }
          refreshPending = true;
          return { ...current, ...source } as OAuthCredential;
        });
      } catch {
        refreshPending = false;
        // Storage/provider errors can contain tokens. Do not echo their messages.
        warn("Codex credentials sync failed: credential storage could not be updated.");
        return;
      }
    }
    if (!refreshPending) return;
    try {
      const result = await ctx.modelRegistry.refresh({ allowNetwork: false, providers: ["openai-codex"] });
      if (result.errors.has("openai-codex")) throw new Error("refresh failed");
      refreshPending = false;
    } catch {
      // The write already succeeded. Retry only the snapshot refresh at the next
      // session boundary, never blindly write the same source again.
      warn("Codex credentials were saved, but Pi's model snapshot could not be refreshed; retrying at the next session start.");
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    if (!inFlight) inFlight = sync(ctx);
    try { await inFlight; } finally { inFlight = undefined; }
  });
}
