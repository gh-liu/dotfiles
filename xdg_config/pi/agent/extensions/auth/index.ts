// Syncs OAuth credentials from ~/.codex/auth.json into Pi's openai-codex provider.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { codexAuth } from "./codex-auth.ts";

type CredentialStore = {
  modify(
    provider: string,
    update: (current: Record<string, unknown> | undefined) => Promise<Record<string, unknown> | undefined>,
  ): Promise<unknown>;
};

type LegacyModelRegistry = {
  runtime?: { credentials?: CredentialStore };
};

function legacyCredentialStore(modelRegistry: unknown): CredentialStore | undefined {
  // ModelRegistry intentionally keeps credential mutation private. Keep this
  // compatibility shim isolated so the rest of the extension only depends on
  // the small operation it needs and fails safely when Pi changes internals.
  const runtime = (modelRegistry as LegacyModelRegistry).runtime;
  return runtime?.credentials;
}

export default function(pi: ExtensionAPI) {
  const [codexCredential, codexCredentialAvailable] = codexAuth();
  let credentialsSynced = false;

  pi.on("session_start", async (_event, ctx) => {
    if (credentialsSynced || !codexCredentialAvailable) return;

    const credentials = legacyCredentialStore(ctx.modelRegistry);
    if (!credentials?.modify) {
      if (ctx.hasUI) {
        ctx.ui.notify("Codex credentials could not be synced: this Pi version does not expose the required credential store.", "warning");
      }
      return;
    }

    try {
      await credentials.modify("openai-codex", async (current) => ({
        ...current,
        ...codexCredential,
      }));

      const result = await ctx.modelRegistry.refresh({
        allowNetwork: false,
        providers: ["openai-codex"],
      });
      const error = result.errors.get("openai-codex");
      if (error) throw error;
      credentialsSynced = true;
    } catch (error) {
      if (ctx.hasUI) {
        ctx.ui.notify(`Codex credentials sync failed: ${error instanceof Error ? error.message : String(error)}`, "warning");
      }
    }
  });
}
