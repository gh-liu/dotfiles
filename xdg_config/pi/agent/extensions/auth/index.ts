import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { codexAuth } from "./codex-auth.ts";

const apiKeyEnvironmentVariables = {
  deepseek: "DEEPSEEK_API_KEY",
  openrouter: "OPENROUTER_API_KEY",
} as const;

export default function(pi: ExtensionAPI) {
  const [codexCredential, codexCredentialAvailable] = codexAuth();
  let credentialsSynced = false;

  pi.on("session_start", async (_event, ctx) => {
    if (credentialsSynced) return;

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

    const apiKeyCredentials = Object.entries(apiKeyEnvironmentVariables)
      .map(([provider, environmentVariable]) => [
        provider,
        process.env[environmentVariable],
      ])
      .filter((credential): credential is [string, string] => Boolean(credential[1]));
    if (!codexCredentialAvailable && apiKeyCredentials.length === 0) return;

    if (codexCredentialAvailable) {
      await credentials.modify("openai-codex", async (current) => ({
        ...current,
        ...codexCredential,
      }));
    }
    for (const [provider, key] of apiKeyCredentials) {
      await credentials.modify(provider, async (current) => ({
        ...current,
        type: "api_key",
        key,
      }));
    }

    await ctx.modelRegistry.refresh();
    credentialsSynced = true;
  });
}
