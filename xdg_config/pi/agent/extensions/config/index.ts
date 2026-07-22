import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { codexAuth } from "./codex-auth.ts";

export default function(pi: ExtensionAPI) {
  const [_codexAuth, codexAuthsynced] = codexAuth();
  pi.on("session_start", async (_event, ctx) => {
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

    if (!codexAuthsynced) return;

    await credentials.modify("openai-codex", async (current) => ({ ...current, ..._codexAuth }));
    await ctx.modelRegistry.refresh();
  });

  pi.on("agent_end", async () => {
    process.stdout.write("\x07");
  });
}
