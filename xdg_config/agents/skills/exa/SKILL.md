---
name: exa
description: Uses Exa Agent for deep research, list building, enrichment, and structured JSON outputs. Use when a task needs multi-step web research, grounded fields, contact or entity enrichment, or follow-up Agent runs.
---

# Exa Agent

Use Exa Agent for asynchronous, high-compute research workflows that need more than a single search call.

## When to use

- Build lists from open-ended criteria, then enrich every result.
- Research entities across many fields with citations or field-level grounding.
- Run multi-hop workflows, such as “find companies, then find decision makers.”
- Produce schema-validated JSON from long-running web research.
- Continue from a previous Agent run with a follow-up request, such as “find 10 more.”
- Enrich existing rows with additional fields using `input.data`.

Do not use Exa Agent for simple low-latency lookup or one-shot web search tasks. Prefer the Exa Search API for those.

## Instructions

1. Confirm the task is suitable for Agent.
   - It should require deep research, list building, enrichment, multi-hop reasoning, or structured output.
   - If the user only needs one fast search or extraction, use Search API instead.
2. Check credentials and prefer curl.
   - Require `EXA_API_KEY` in the environment.
   - Use direct HTTP requests with `curl` by default. Do not add an SDK dependency unless the surrounding project already uses one or repeated programmatic calls justify it.
   - Use `x-api-key: $EXA_API_KEY` for authentication. `Authorization: Bearer $EXA_API_KEY` is also supported, but keep examples on `x-api-key`.
3. Create an Agent run.
   - Write a precise `query` with clear success criteria, target count, required fields, exclusions, and freshness requirements.
   - Set `effort` deliberately. Use `medium` for standard single-entity research, `auto` for variable-scope list building, `low` or `minimal` for narrow low-cost tasks, and `high` or `xhigh` when completeness matters more than cost or latency.
   - For structured outputs, pass `outputSchema` and bound arrays with `maxItems` when possible.
4. Wait for completion.
   - Use streaming (`Accept: text/event-stream` with `curl -N`) when progress events matter.
   - Otherwise save the returned run `id` and poll until a terminal status.
5. Read results from the completed run.
   - `output.text`: natural-language answer.
   - `output.structured`: JSON validated against the requested schema.
   - `output.grounding`: citations for text or structured fields when emitted.
   - `costDollars` and `usage`: cost and usage information.
6. Preserve run IDs.
   - Store run IDs in notes, logs, or downstream state when follow-up runs may be needed.
   - Use `previousRunId` for continuation requests.

## curl quickstart

Create a run and save its ID. Examples use `jq` only for local JSON filtering.

```bash
RUN_ID=$(
  curl -s -X POST "https://api.exa.ai/agent/runs" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $EXA_API_KEY" \
    -d '{
      "query": "What are the most important AI infrastructure funding rounds announced this week?",
      "effort": "medium"
    }' \
  | jq -r '.id'
)

echo "$RUN_ID"
```

Poll the run until it reaches `completed`, `failed`, or `cancelled`:

```bash
curl -s "https://api.exa.ai/agent/runs/$RUN_ID" \
  -H "x-api-key: $EXA_API_KEY" \
| jq '{id, status, stopReason, output, usage, costDollars}'
```

Stream run lifecycle events instead of polling:

```bash
curl -N -X POST "https://api.exa.ai/agent/runs" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -H "x-api-key: $EXA_API_KEY" \
  -d '{
    "query": "Find five recently launched developer tools for evaluating AI agents.",
    "effort": "auto"
  }'
```

## Structured output

Use `outputSchema` when the caller needs a specific machine-readable shape. Prefer explicit JSON Schema with required fields and bounded arrays.

```bash
curl -s -X POST "https://api.exa.ai/agent/runs" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $EXA_API_KEY" \
  -d '{
    "query": "Find AI infrastructure companies that raised a Series A or B in the last 6 months.",
    "effort": "auto",
    "outputSchema": {
      "type": "object",
      "properties": {
        "companies": {
          "type": "array",
          "maxItems": 10,
          "items": {
            "type": "object",
            "properties": {
              "name": { "type": "string" },
              "round": { "type": "string" },
              "website": { "type": "string", "format": "uri" }
            },
            "required": ["name", "round"]
          }
        }
      },
      "required": ["companies"]
    }
  }' \
| jq .
```

For contact fields, describe the desired fields in the schema. Use standard formats such as `email`, `phone`, and `uri`. Bound list sizes with `maxItems` to keep contact-enrichment cost predictable.

## Input rows and exclusions

Use `input.data` to enrich existing rows instead of asking Agent to rediscover them. Use `input.exclusion` to prevent known or already-processed entities from being returned again.

```bash
curl -s -X POST "https://api.exa.ai/agent/runs" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $EXA_API_KEY" \
  -d '{
    "query": "Find the top 10 cutest animals. Return the common name and a source URL for each animal.",
    "input": {
      "exclusion": [
        { "animal": "goat" },
        { "animal": "panda" }
      ]
    }
  }'
```

## Data sources

Use `dataSources` when premium Exa Connect data partners are needed. Each entry selects a provider.

```bash
curl -s -X POST "https://api.exa.ai/agent/runs" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $EXA_API_KEY" \
  -d '{
    "query": "Find 10 fast-growing B2B SaaS companies and their estimated web traffic.",
    "dataSources": [
      { "provider": "similarweb" },
      { "provider": "fiber_ai" }
    ]
  }'
```

When a schema property asks for data from a specific source, such as “from Similarweb,” Agent will prefer the matching provider tool over generic web search.

## Continuing and listing runs

Continue from a previous completed run when the user asks a follow-up.

```bash
curl -s -X POST "https://api.exa.ai/agent/runs" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $EXA_API_KEY" \
  -d '{
    "query": "Narrow that list to companies hiring in San Francisco.",
    "previousRunId": "agent_run_01j..."
  }'
```

List recent runs to recover run IDs or inspect statuses.

```bash
curl -s "https://api.exa.ai/agent/runs?limit=10" \
  -H "x-api-key: $EXA_API_KEY" \
| jq -r '.data[] | [.id, .status, .createdAt, (.request.query // "")] | @tsv'
```

## Cost and effort guidance

- Agent pricing is usage-based. Cost can include Agent Compute Units, search tool calls, and separate contact enrichment charges.
- Fixed effort modes: `minimal`, `low`, `medium`, `high`, `xhigh`.
- `auto` is the default and is best for variable-scope work where entity count or complexity is unknown.
- Use `medium` as the default starting point for standard single-entity research.
- Move down to `low` or `minimal` when cost and latency matter more than completeness.
- Move up to `high` or `xhigh` when the schema is larger, fields require verification, or the task needs deeper reasoning.

## Safety and quality rules

- Never print or commit `EXA_API_KEY`.
- Do not send secrets, private credentials, or unnecessary personal data in queries, schemas, or input rows.
- Exa Agent is not ZDR. If zero data retention is required, do not use Agent unless the account has an appropriate arrangement with Exa.
- Keep prompts specific: include required fields, target count, freshness, geography, exclusions, and acceptable sources.
- Prefer schemas over prose-only instructions when downstream code consumes the result.
- Check `output.grounding` or cited sources before treating high-impact facts as verified.
- Report cost-related uncertainty when using `auto`, large `input.data`, broad list-building prompts, or contact enrichment.
