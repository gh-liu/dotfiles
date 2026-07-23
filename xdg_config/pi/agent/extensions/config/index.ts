import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { codexAuth } from "./codex-auth.ts";

export default function(pi: ExtensionAPI) {
  const [_codexAuth, codexAuthsynced] = codexAuth();
  let _codexAuthsynced = false;
  pi.on("session_start", async (_event, ctx) => {
    if (_codexAuthsynced) return;

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
    _codexAuthsynced = true;
  });

  pi.on("agent_end", async () => {
    process.stdout.write("\x07");
  });
}
