export const DEEPSEEK_STATUS_KEY = "deepseek-balance";
export const DEEPSEEK_PROVIDER = "deepseek";

export interface DeepSeekBalanceResponse {
  balance_infos?: Array<{ currency?: string; total_balance?: string }>;
}

export interface ProviderAuthResult {
  ok?: boolean;
  apiKey?: string;
  headers?: HeadersInit;
}

export function resolveDeepSeekAccessTokenFromProviderAuth(
  auth: ProviderAuthResult | undefined,
): string {
  const authorization = new Headers(auth?.headers).get("authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1] ?? auth?.apiKey;

  if (!token) {
    throw new Error("No token available for deepseek");
  }

  return token;
}

export async function fetchDeepSeekBalance(token: string): Promise<DeepSeekBalanceResponse> {
  const response = await fetch("https://api.deepseek.com/user/balance", {
    method: "GET",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
    },
  });

  if (!response.ok) {
    throw new Error(`DeepSeek balance request failed: ${response.status} ${response.statusText}`);
  }

  return (await response.json()) as DeepSeekBalanceResponse;
}

export function formatDeepSeekBalanceStatus(data: DeepSeekBalanceResponse): string {
  const total =
    data.balance_infos?.reduce((sum, item) => sum + Number(item.total_balance ?? 0), 0) ?? 0;
  return `deepseek ¥${total.toFixed(2)}`;
}
