import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  CODEX_PROVIDER,
  CODEX_STATUS_KEY,
  fetchCodexUsage,
  formatCodexUsageStatus,
  resolveCodexAccessTokenFromProviderAuth,
} from "./codex-usage.ts";
import { syncCodexAuthFromCodexCli } from "./codex-auth.ts";
import {
  DEEPSEEK_PROVIDER,
  DEEPSEEK_STATUS_KEY,
  fetchDeepSeekBalance,
  formatDeepSeekBalanceStatus,
  resolveDeepSeekAccessTokenFromProviderAuth,
} from "./deepseek-balance.ts";

export default function(pi: ExtensionAPI) {
  async function getCodexAccessToken(ctx: ExtensionContext) {
    if (!ctx.model) throw new Error("No active model for openai-codex usage request");
    return resolveCodexAccessTokenFromProviderAuth(await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model));
  }

  async function getDeepSeekAccessToken(ctx: ExtensionContext) {
    if (!ctx.model) throw new Error("No active model for deepseek balance request");
    return resolveDeepSeekAccessTokenFromProviderAuth(await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model));
  }

  async function syncCodexStatus(provider: string | undefined, ctx: ExtensionContext) {
    if (provider !== CODEX_PROVIDER) {
      ctx.ui.setStatus(CODEX_STATUS_KEY, undefined);
      return;
    }

    syncCodexAuthFromCodexCli(ctx.modelRegistry.authStorage);

    try {
      const usage = await fetchCodexUsage(await getCodexAccessToken(ctx));
      const text = formatCodexUsageStatus(usage);
      const suffix = text.slice("codex".length);
      ctx.ui.setStatus(CODEX_STATUS_KEY, ctx.ui.theme.fg("accent", "codex") + ctx.ui.theme.fg("muted", suffix));
    } catch {
      ctx.ui.setStatus(CODEX_STATUS_KEY, undefined);
    }
  }

  async function syncDeepSeekStatus(provider: string | undefined, ctx: ExtensionContext) {
    if (provider !== DEEPSEEK_PROVIDER) {
      ctx.ui.setStatus(DEEPSEEK_STATUS_KEY, undefined);
      return;
    }

    try {
      const text = formatDeepSeekBalanceStatus(await fetchDeepSeekBalance(await getDeepSeekAccessToken(ctx)));
      const suffix = text.slice("deepseek".length);
      ctx.ui.setStatus(DEEPSEEK_STATUS_KEY, ctx.ui.theme.fg("accent", "deepseek") + ctx.ui.theme.fg("muted", suffix));
    } catch {
      ctx.ui.setStatus(DEEPSEEK_STATUS_KEY, undefined);
    }
  }

  async function syncProviderStatus(provider: string | undefined, ctx: ExtensionContext) {
    await syncCodexStatus(provider, ctx);
    await syncDeepSeekStatus(provider, ctx);
  }

  pi.on("session_start", async (_event, ctx) => {
    syncCodexAuthFromCodexCli(ctx.modelRegistry.authStorage);
    await syncProviderStatus(ctx.model?.provider, ctx);
  });

  pi.on("model_select", async (event, ctx) => {
    await syncProviderStatus(event.model.provider, ctx);
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    ctx.ui.setStatus(CODEX_STATUS_KEY, undefined);
    ctx.ui.setStatus(DEEPSEEK_STATUS_KEY, undefined);
  });

  pi.on("agent_end", async () => {
    process.stdout.write("\x07");
  });
}
