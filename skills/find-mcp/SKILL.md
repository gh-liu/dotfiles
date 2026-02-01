---
name: find-mcp
description: Search and discover MCP servers from the official Model Context Protocol registry. Use this skill when users want to find MCP servers, explore available integrations, or discover new capabilities.
license: MIT
---

# Find MCP Servers

This skill helps you search and discover MCP (Model Context Protocol) servers from the official registry at https://registry.modelcontextprotocol.io.

## MCP Registry API

Base URL: `https://registry.modelcontextprotocol.io`

### Search Servers

```
GET /v0.1/servers
```

**Query Parameters:**
- `search` - Search by server name (substring match)
- `limit` - Number of results per page (1-100, default: 30)
- `cursor` - Pagination cursor for next page
- `version` - Filter by version (use "latest" for latest version)
- `updated_since` - Filter servers updated since RFC3339 timestamp

**Example Requests:**
```bash
# Search for filesystem-related servers
curl "https://registry.modelcontextprotocol.io/v0.1/servers?search=filesystem"

# Get latest 50 servers
curl "https://registry.modelcontextprotocol.io/v0.1/servers?limit=50&version=latest"

# Search for brave search
curl "https://registry.modelcontextprotocol.io/v0.1/servers?search=brave"
```

**Response Structure:**
```json
{
  "servers": [
    {
      "_meta": {
        "io.modelcontextprotocol.registry/official": {
          "status": "active",
          "publishedAt": "2025-01-15T10:00:00Z",
          "isLatest": true,
          "updatedAt": "2025-01-20T15:30:00Z"
        }
      },
      "server": {
        "name": "io.github.example/filesystem",
        "title": "Filesystem Access",
        "description": "MCP server for filesystem operations",
        "version": "1.0.2",
        "repository": {
          "url": "https://github.com/example/mcp-filesystem",
          "source": "github"
        },
        "packages": [...]
      }
    }
  ],
  "metadata": {
    "count": 1,
    "nextCursor": "cursor123"
  }
}
```

### Get Specific Server

```
GET /v0.1/servers/{serverName}/versions/{version}
```

**Parameters:**
- `serverName` - URL-encoded server name (e.g., `com.example%2Fmy-server`)
- `version` - Version number or "latest"

**Example:**
```bash
# Get latest version of brave search server
curl "https://registry.modelcontextprotocol.io/v0.1/servers/io.modelcontextprotocol.servers%2Fbrave-search/versions/latest"
```

### Get All Versions of a Server

```
GET /v0.1/servers/{serverName}/versions
```

## Common Search Patterns

### By Category/Functionality
- **File operations**: `search=filesystem`
- **Search tools**: `search=brave`, `search=google`
- **Development**: `search=github`, `search=git`
- **Data processing**: `search=csv`, `search=json`
- **Web scraping**: `search=fetch`, `search=web`
- **Database**: `search=postgres`, `search=sqlite`, `search=database`

### By Transport Type
Servers support different transport types:
- **stdio** - Standard input/output (most common for npm packages)
- **sse** - Server-Sent Events
- **streamable-http** - Streaming HTTP

### Filter by Registry Type
- **npm** - Node.js packages (@modelcontextprotocol/server-*)
- **pypi** - Python packages
- **oci** - OCI containers
- **mcpb** - MCP binary format

## Installation Instructions

When presenting MCP servers to users, include installation instructions based on package type:

### NPM Packages
```bash
npx @modelcontextprotocol/server-<name>
```

### With Configuration
Many servers require configuration (API keys, etc.). Show the `packageArguments` from the registry response:

```json
{
  "packageArguments": [
    {
      "name": "--api-key",
      "description": "API key for service",
      "isRequired": true,
      "isSecret": true
    }
  ]
}
```

## Search Strategy

1. **Start with broad search terms** - Use single keywords first
2. **Use substring matching** - The API searches within server names and descriptions
3. **Check multiple pages** - Use `nextCursor` from `metadata` for pagination
4. **Filter for latest** - Always use `version=latest` for production use
5. **Verify status** - Check `_meta.io.modelcontextprotocol.registry/official.status` is "active"

## Server Information to Present

When displaying results to users, show:
- **Title/Name** - Human-readable name and reverse-DNS identifier
- **Description** - What the server does
- **Repository** - Source code location
- **Version** - Latest version number
- **Transport** - How it connects (stdio/sse/http)
- **Package Type** - npm, pypi, etc.
- **Installation Command** - How to install
- **Configuration** - Required arguments/inputs

## Error Handling

API returns errors in RFC 7807 format (application/problem+json):
```json
{
  "type": "https://example.com/errors/example",
  "title": "Bad Request",
  "status": 400,
  "detail": "Property foo is required but is missing."
}
```

Common errors:
- **400** - Invalid query parameters
- **404** - Server not found
- **422** - Validation error

## Examples

### Find All Official MCP Servers
```bash
curl "https://registry.modelcontextprotocol.io/v0.1/servers?limit=100&version=latest"
```

### Find GitHub Integration
```bash
curl "https://registry.modelcontextprotocol.io/v0.1/servers?search=github&version=latest"
```

### Get Brave Search Details
```bash
curl "https://registry.modelcontextprotocol.io/v0.1/servers/io.modelcontextprotocol.servers%2Fbrave-search/versions/latest"
```

## Related Resources

- MCP Registry: https://registry.modelcontextprotocol.io
- MCP Documentation: https://modelcontextprotocol.io
- MCP Servers Repository: https://github.com/modelcontextprotocol/servers
