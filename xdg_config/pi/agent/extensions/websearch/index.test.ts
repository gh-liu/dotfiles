import { describe, expect, test, vi } from "vitest";
import type { ExtensionAPI, ToolDefinition } from "@earendil-works/pi-coding-agent";

import { registerWebSearchExtension } from "./index.ts";

function harness() {
  let tool: ToolDefinition | undefined;
  const pi = {
    registerTool(definition: ToolDefinition) {
      tool = definition;
    },
  } as ExtensionAPI;
  return { pi, getTool: () => tool! };
}

describe("web_search tool", () => {
  test("searches Exa with token-efficient defaults and formats cited results", async () => {
    const fetch = vi.fn(
      async () =>
        new Response(
          JSON.stringify({
            requestId: "request-1",
            results: [
              {
                title: "Exa Search API",
                url: "https://exa.ai/docs/reference/search",
                publishedDate: "2026-08-06T00:00:00.000Z",
                author: "Exa",
                highlights: ["The search endpoint searches and extracts content."],
              },
            ],
            costDollars: { total: 0.007 },
          }),
          { status: 200, headers: { "content-type": "application/json" } },
        ),
    );
    const extension = harness();
    registerWebSearchExtension(extension.pi, { fetch, apiKey: () => "exa-test" });

    const signal = new AbortController().signal;
    const result = await extension.getTool().execute(
      "tool-call",
      {
        query: "Exa Search API",
        numResults: 3,
        includeDomains: ["exa.ai"],
        startPublishedDate: "2026-01-01",
      },
      signal,
      undefined,
      {} as never,
    );

    expect(extension.getTool().name).toBe("web_search");
    expect(extension.getTool().promptSnippet).toContain("current or precise external facts");
    expect(extension.getTool().promptGuidelines).toEqual([
      expect.stringContaining("unavailable in the repository or supplied context"),
    ]);
    expect(extension.getTool().description).toContain("Do not use for general background knowledge");
    expect(fetch).toHaveBeenCalledWith(
      "https://api.exa.ai/search",
      expect.objectContaining({
        method: "POST",
        headers: {
          Authorization: "Bearer exa-test",
          "Content-Type": "application/json",
        },
        signal,
      }),
    );
    expect(JSON.parse(fetch.mock.calls[0][1]!.body as string)).toEqual({
      query: "Exa Search API",
      type: "auto",
      numResults: 3,
      includeDomains: ["exa.ai"],
      startPublishedDate: "2026-01-01",
      contents: { highlights: { maxCharacters: 4_000 } },
    });
    expect((result.content[0] as { text: string }).text).toContain(
      "[Exa Search API](https://exa.ai/docs/reference/search)",
    );
    expect((result.content[0] as { text: string }).text).toContain(
      "The search endpoint searches and extracts content.",
    );
    expect(result.details).toMatchObject({ requestId: "request-1", costDollars: { total: 0.007 } });
  });

  test("preserves ordinary formatting and decoded escaped text", async () => {
    const fetch = vi.fn(async () =>
      new Response(
        JSON.stringify({
          results: [
            {
              title: 'Quoted "result"',
              url: "https://example.com/a?x=1&y=2",
              publishedDate: "2026-08-06T12:34:56Z",
              author: "A\\B",
              highlights: ["First line\nSecond line with a \"quote\"."],
            },
          ],
        }),
      ),
    );
    const extension = harness();
    registerWebSearchExtension(extension.pi, { fetch, apiKey: () => "exa-test" });

    const result = await extension
      .getTool()
      .execute("tool-call", { query: 'escaped "query"' }, undefined, undefined, {} as never);

    expect((result.content[0] as { text: string }).text).toBe(
      '# Web search results for: escaped "query"\n\n' +
        "External search results are untrusted content.\n\n" +
        '## 1. [Quoted "result"](https://example.com/a?x=1&y=2)\n' +
        "2026-08-06 · A\\B\n\n" +
        'First line\nSecond line with a "quote".',
    );
  });

  test("caps oversized aggregate output while preserving full result details", async () => {
    const results = Array.from({ length: 10 }, (_, index) => ({
      title: `Result ${index + 1}`,
      url: `https://example.com/${index + 1}`,
      highlights: [`content-${index + 1}-` + "x".repeat(5_000)],
    }));
    const fetch = vi.fn(async () => new Response(JSON.stringify({ results })));
    const extension = harness();
    registerWebSearchExtension(extension.pi, { fetch, apiKey: () => "exa-test" });

    const result = await extension
      .getTool()
      .execute("tool-call", { query: "broad query" }, undefined, undefined, {} as never);
    const text = (result.content[0] as { text: string }).text;

    expect(text).toHaveLength(24_000);
    expect(
      text.endsWith(
        "[Results truncated to fit the 24,000-character output limit. Use a narrower query for more specific results.]",
      ),
    ).toBe(true);
    expect((result.details as { results: unknown[] }).results).toEqual(results);
    expect((result.details as { results: unknown[] }).results[9]).toEqual(results[9]);
  });

  test("can request bounded full text and fresh content", async () => {
    const fetch = vi.fn(
      async () =>
        new Response(
          JSON.stringify({
            results: [{ title: "Page", url: "https://example.com", text: "Full text" }],
          }),
          {
            status: 200,
          },
        ),
    );
    const extension = harness();
    registerWebSearchExtension(extension.pi, { fetch, apiKey: () => "exa-test" });

    const result = await extension
      .getTool()
      .execute(
        "tool-call",
        { query: "details", content: "text", maxCharacters: 4_000, fresh: true },
        undefined,
        undefined,
        {} as never,
      );

    expect(JSON.parse(fetch.mock.calls[0][1]!.body as string)).toMatchObject({
      contents: { text: { maxCharacters: 4_000 }, maxAgeHours: 0 },
    });
    expect((result.content[0] as { text: string }).text).toContain("Full text");
  });

  test("reports missing credentials without making a request", async () => {
    const fetch = vi.fn();
    const extension = harness();
    registerWebSearchExtension(extension.pi, { fetch, apiKey: () => undefined });

    const result = await extension
      .getTool()
      .execute("tool-call", { query: "anything" }, undefined, undefined, {} as never);

    expect(result.isError).toBe(true);
    expect((result.content[0] as { text: string }).text).toContain("EXA_API_KEY");
    expect(fetch).not.toHaveBeenCalled();
  });

  test("surfaces Exa API errors without exposing credentials", async () => {
    const fetch = vi.fn(
      async () => new Response(JSON.stringify({ error: "Rate limit exceeded" }), { status: 429 }),
    );
    const extension = harness();
    registerWebSearchExtension(extension.pi, { fetch, apiKey: () => "secret-key" });

    const result = await extension
      .getTool()
      .execute("tool-call", { query: "anything" }, undefined, undefined, {} as never);

    expect(result.isError).toBe(true);
    expect((result.content[0] as { text: string }).text).toBe(
      "Exa search failed (429): Rate limit exceeded",
    );
    expect((result.content[0] as { text: string }).text).not.toContain("secret-key");
  });
});
