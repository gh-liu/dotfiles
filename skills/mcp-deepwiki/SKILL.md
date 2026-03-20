---
name: mcp-deepwiki
description: Use MCPorter to call the official DeepWiki MCP server for public GitHub repository documentation lookup, wiki structure browsing, and repository Q&A. Use this when a task needs DeepWiki's read_wiki_structure, read_wiki_contents, or ask_question tools from the CLI or TypeScript.
---

# MCP DeepWiki

Use this skill when you need DeepWiki's repository-aware documentation tools through `mcporter`.

DeepWiki MCP is for public GitHub repositories. If the repository is private or requires authenticated access, do not use this skill; use Devin MCP or another authenticated integration instead.

## Default approach

Prefer the official Streamable HTTP endpoint:

```text
https://mcp.deepwiki.com/mcp
```

Start by inspecting the live tool schema so you use the server's current parameter names instead of guessing:

```bash
npx mcporter list https://mcp.deepwiki.com/mcp --all-parameters
```

DeepWiki exposes three tools:

- `read_wiki_structure`: list available documentation areas for a repo.
- `read_wiki_contents`: read DeepWiki documentation for a repo.
- `ask_question`: ask a grounded question about a repo.

## CLI usage

For one-off calls, use MCPorter directly against the HTTP endpoint and prefer function-call syntax.

Common pattern:

```bash
npx mcporter call 'https://mcp.deepwiki.com/mcp.<tool_name>(...)'
```

Examples:

```bash
npx mcporter call 'https://mcp.deepwiki.com/mcp.read_wiki_structure(repoName: "facebook/react")'
```

```bash
npx mcporter call 'https://mcp.deepwiki.com/mcp.ask_question(repoName: "vercel/next.js", question: "How does the App Router data fetching model work?")'
```

If you need the exact argument list for `read_wiki_contents` or any future schema change, re-run:

```bash
npx mcporter list https://mcp.deepwiki.com/mcp --all-parameters
```

## Repeated use

If you will call DeepWiki more than once in the same project, persist it in `config/mcporter.json`:

```json
{
  "mcpServers": {
    "deepwiki": {
      "baseUrl": "https://mcp.deepwiki.com/mcp"
    }
  }
}
```

Then use the named server:

```bash
npx mcporter list deepwiki --all-parameters
npx mcporter call 'deepwiki.read_wiki_structure(repoName: "facebook/react")'
npx mcporter call 'deepwiki.ask_question(repoName: "vercel/next.js", question: "How does middleware execution order work?")'
```

## TypeScript usage

For automation, use MCPorter's runtime and proxy API after adding `deepwiki` to `config/mcporter.json`:

```ts
import { createRuntime, createServerProxy } from "mcporter";

const runtime = await createRuntime();
const deepwiki = createServerProxy(runtime, "deepwiki");

const structure = await deepwiki.readWikiStructure({
  repoName: "facebook/react",
});

console.log(structure.text());

const answer = await deepwiki.askQuestion({
  repoName: "vercel/next.js",
  question: "How does the App Router data cache work?",
});

console.log(answer.text());
await runtime.close();
```

## Working rules

- Prefer `read_wiki_structure` before deep reads when you do not already know the documentation area you need.
- Use `ask_question` for synthesis and `read_wiki_contents` for source-oriented reading.
- Quote `owner/repo` exactly as GitHub names it.
- Re-list the schema if a call fails due to parameter mismatch; do not hard-code old argument names.
- Prefer `/mcp`; do not choose legacy SSE unless a client explicitly requires it.
