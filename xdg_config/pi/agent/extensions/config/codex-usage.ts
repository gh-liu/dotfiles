export const CODEX_STATUS_KEY = "codex-usage";
export const CODEX_PROVIDER = "openai-codex";

export interface CodexUsageResponse {
  rate_limit: {
    primary_window: { used_percent: number; reset_at: number };
    secondary_window: { used_percent: number; reset_at: number };
  };
}

export interface ProviderAuthResult {
  ok?: boolean;
  apiKey?: string;
  headers?: HeadersInit;
}

function remainingPercent(usedPercent: number): number {
  return Math.max(0, Math.min(100, Math.round(100 - usedPercent)));
}

export function formatCodexUsageStatus(data: CodexUsageResponse): string {
  const primary = remainingPercent(data.rate_limit.primary_window.used_percent);
  const secondary = remainingPercent(data.rate_limit.secondary_window.used_percent);
  return `codex 5h ${primary}% / 1w ${secondary}%`;
}

export function resolveCodexAccessTokenFromProviderAuth(auth: ProviderAuthResult | undefined): string {
  const authorization = new Headers(auth?.headers).get("authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1] ?? auth?.apiKey;

  if (!token) {
    throw new Error("No token available for openai-codex");
  }

  return token;
}

export async function fetchCodexUsage(token: string): Promise<CodexUsageResponse> {
  const response = await fetch("https://chatgpt.com/backend-api/wham/usage", {
    method: "GET",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Codex usage request failed: ${response.status} ${response.statusText}`);
  }

  return (await response.json()) as CodexUsageResponse;
}
