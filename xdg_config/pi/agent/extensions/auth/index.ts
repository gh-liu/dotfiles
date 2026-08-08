// Syncs OAuth credentials from ~/.codex/auth.json into Pi's openai-codex provider.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { codexAuth } from "./codex-auth.ts";

export default function(pi: ExtensionAPI) {
  const [codexCredential, codexCredentialAvailable] = codexAuth();
  let credentialsSynced = false;

  pi.on("session_start", async (_event, ctx) => {
    if (credentialsSynced || !codexCredentialAvailable) return;

    const credentials = (
      ctx.modelRegistry as unknown as {
        runtime?: {
          credentials?: {
            modify?: (
              provider: string,
              update: (
                current: Record<string, unknown> | undefined,
              ) => Promise<Record<string, unknown> | undefined>,
            ) => Promise<unknown>;
          };
        };
      }
    ).runtime?.credentials;
    if (!credentials?.modify) return;

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
  });
}
