import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { codexAuth } from "./codex-auth.ts";

export default function(pi: ExtensionAPI) {
  const [_codexAuth, codexAuthsynced] = codexAuth();
  const deepseekApiKey = process.env.DEEPSEEK_API_KEY;
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

    if (!codexAuthsynced && !deepseekApiKey) return;

    if (codexAuthsynced) {
      await credentials.modify("openai-codex", async (current) => ({
        ...current,
        ..._codexAuth,
      }));
    }
    if (deepseekApiKey) {
      await credentials.modify("deepseek", async (current) => ({
        ...current,
        type: "api_key",
        key: deepseekApiKey,
      }));
    }

    await ctx.modelRegistry.refresh();
    credentialsSynced = true;
  });

  pi.on("agent_end", async () => {
    process.stdout.write("\x07");
  });
}
