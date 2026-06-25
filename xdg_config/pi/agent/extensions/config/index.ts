import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  CODEX_PROVIDER,
  CODEX_STATUS_KEY,
  fetchCodexUsage,
  formatCodexUsageStatus,
  resolveCodexAccessTokenFromProviderAuth,
} from "./codex-usage.ts";

export default function(pi: ExtensionAPI) {
  async function syncCodexStatus(provider: string | undefined, ctx: ExtensionContext) {
    if (provider !== CODEX_PROVIDER) {
      ctx.ui.setStatus(CODEX_STATUS_KEY, undefined);
      return;
    }

    try {
      if (!ctx.model) throw new Error("No active model for openai-codex usage request");
      const usage = await fetchCodexUsage(
        resolveCodexAccessTokenFromProviderAuth(await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model)),
      );
      const text = formatCodexUsageStatus(usage);
      const suffix = text.slice("codex".length);
      ctx.ui.setStatus(CODEX_STATUS_KEY, ctx.ui.theme.fg("accent", "codex") + ctx.ui.theme.fg("muted", suffix));
    } catch {
      ctx.ui.setStatus(CODEX_STATUS_KEY, undefined);
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    await syncCodexStatus(ctx.model?.provider, ctx);
  });

  pi.on("model_select", async (event, ctx) => {
    await syncCodexStatus(event.model.provider, ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    ctx.ui.setStatus(CODEX_STATUS_KEY, undefined);
  });

  pi.on("agent_end", async () => {
    process.stdout.write("\x07");
  });
}
