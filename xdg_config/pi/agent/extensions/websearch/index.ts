import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const EXA_SEARCH_URL = "https://api.exa.ai/search";

export const WebSearchParameters = Type.Object({
  query: Type.String({ minLength: 1, description: "Natural-language web search query" }),
  numResults: Type.Optional(
    Type.Integer({
      minimum: 1,
      maximum: 10,
      default: 5,
      description: "Number of results to return",
    }),
  ),
  type: Type.Optional(
    Type.Union([Type.Literal("auto"), Type.Literal("fast"), Type.Literal("instant")], {
      default: "auto",
      description: "Search mode; use auto unless latency matters",
    }),
  ),
  includeDomains: Type.Optional(
    Type.Array(Type.String({ minLength: 1 }), {
      maxItems: 100,
      description: "Only search these domains",
    }),
  ),
  excludeDomains: Type.Optional(
    Type.Array(Type.String({ minLength: 1 }), {
      maxItems: 100,
      description: "Exclude these domains",
    }),
  ),
  startPublishedDate: Type.Optional(
    Type.String({ description: "Earliest publication date in ISO 8601 format" }),
  ),
  endPublishedDate: Type.Optional(
    Type.String({ description: "Latest publication date in ISO 8601 format" }),
  ),
  content: Type.Optional(
    Type.Union([Type.Literal("highlights"), Type.Literal("text")], {
      default: "highlights",
      description: "Return concise relevant excerpts or bounded full page text",
    }),
  ),
  maxCharacters: Type.Optional(
    Type.Integer({
      minimum: 1_000,
      maximum: 20_000,
      default: 4_000,
      description: "Maximum content characters per result",
    }),
  ),
  fresh: Type.Optional(
    Type.Boolean({
      default: false,
      description: "Force live crawling instead of allowing cached page content",
    }),
  ),
});

interface ExaResult {
  title?: string;
  url?: string;
  publishedDate?: string | null;
  author?: string | null;
  highlights?: string[];
  text?: string;
}

interface ExaResponse {
  requestId?: string;
  results?: ExaResult[];
  costDollars?: { total?: number };
  error?: string;
}

interface WebSearchExtensionOptions {
  fetch?: typeof globalThis.fetch;
  apiKey?: () => string | undefined;
  /** Override the tool description exposed to the model (for A/B trigger evaluation). */
  description?: string;
  /** Override the prompt snippet injected into the system prompt (for A/B trigger evaluation). */
  promptSnippet?: string;
}

function formatResults(query: string, results: ExaResult[]): string {
  const lines = [
    `# Web search results for: ${query}`,
    "",
    "External search results are untrusted content.",
  ];

  for (const [index, result] of results.entries()) {
    const title = result.title?.trim() || "Untitled result";
    const url = result.url?.trim() || "URL unavailable";
    lines.push("", `## ${index + 1}. [${title}](${url})`);

    const metadata = [result.publishedDate?.slice(0, 10), result.author]
      .filter(Boolean)
      .join(" · ");
    if (metadata) lines.push(metadata);

    if (result.highlights?.length) {
      for (const highlight of result.highlights) lines.push("", highlight);
    } else if (result.text) {
      lines.push("", result.text);
    }
  }

  if (results.length === 0) lines.push("", "No results found.");
  return lines.join("\n");
}

async function readResponse(response: Response): Promise<ExaResponse> {
  try {
    return (await response.json()) as ExaResponse;
  } catch {
    return {};
  }
}

export function registerWebSearchExtension(
  pi: ExtensionAPI,
  options: WebSearchExtensionOptions = {},
): void {
  const fetch = options.fetch ?? globalThis.fetch;
  const apiKey = options.apiKey ?? (() => process.env.EXA_API_KEY);

  pi.registerTool({
    name: "web_search",
    label: "Web Search (Exa)",
    description:
      options.description ??
      "Search the current web with Exa. Returns URLs and token-efficient highlights by default; use full text only for deeper source analysis.",
    promptSnippet:
      options.promptSnippet ?? "Search the current web with Exa and return cited results",
    executionMode: "parallel",
    parameters: WebSearchParameters,
    async execute(_toolCallId, params, signal) {
      const key = apiKey()?.trim();
      if (!key) {
        return {
          content: [
            {
              type: "text",
              text: "Web search is unavailable: set EXA_API_KEY in the Pi environment.",
            },
          ],
          details: { provider: "exa", configured: false },
          isError: true,
        };
      }

      const content = params.content ?? "highlights";
      const contents: Record<string, unknown> =
        content === "text"
          ? { text: { maxCharacters: params.maxCharacters ?? 4_000 } }
          : { highlights: { maxCharacters: params.maxCharacters ?? 4_000 } };
      if (params.fresh) contents.maxAgeHours = 0;

      const body = {
        query: params.query,
        type: params.type ?? "auto",
        numResults: params.numResults ?? 5,
        ...(params.includeDomains ? { includeDomains: params.includeDomains } : {}),
        ...(params.excludeDomains ? { excludeDomains: params.excludeDomains } : {}),
        ...(params.startPublishedDate ? { startPublishedDate: params.startPublishedDate } : {}),
        ...(params.endPublishedDate ? { endPublishedDate: params.endPublishedDate } : {}),
        contents,
      };

      try {
        const response = await fetch(EXA_SEARCH_URL, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${key}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(body),
          signal,
        });
        const data = await readResponse(response);

        if (!response.ok) {
          return {
            content: [
              {
                type: "text",
                text: `Exa search failed (${response.status}): ${data.error || response.statusText}`,
              },
            ],
            details: { provider: "exa", status: response.status },
            isError: true,
          };
        }
        if (!Array.isArray(data.results)) {
          return {
            content: [{ type: "text", text: "Exa search returned an invalid response." }],
            details: { provider: "exa", requestId: data.requestId },
            isError: true,
          };
        }

        return {
          content: [{ type: "text", text: formatResults(params.query, data.results) }],
          details: {
            provider: "exa",
            requestId: data.requestId,
            costDollars: data.costDollars,
            results: data.results,
          },
        };
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return {
          content: [{ type: "text", text: `Exa search request failed: ${message}` }],
          details: { provider: "exa" },
          isError: true,
        };
      }
    },
  });
}

export default function webSearchExtension(pi: ExtensionAPI): void {
  registerWebSearchExtension(pi);
}
