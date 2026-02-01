# find-mcp Skill

A skill for searching and discovering MCP (Model Context Protocol) servers from the official registry.

## Installation

The skill is installed at `~/.agents/skills/find-mcp/`

## Usage Examples

### Search for Filesystem Servers
```bash
curl "https://registry.modelcontextprotocol.io/v0.1/servers?search=filesystem&limit=5&version=latest"
```

Results include:
- `io.github.Digital-Defiance/mcp-filesystem` - Advanced filesystem operations with security boundaries
- `io.github.bytedance/mcp-server-filesystem` - Filesystem access
- `io.github.domdomegg/filesystem-mcp` - Read, create, and edit files

### Search for Brave Search
```bash
curl "https://registry.modelcontextprotocol.io/v0.1/servers?search=brave&version=latest"
```

Results include:
- `io.github.brave/brave-search-mcp-server` - Official Brave Search server

### Get Latest Servers
```bash
curl "https://registry.modelcontextprotocol.io/v0.1/servers?limit=20&version=latest"
```

### Get Server Details
```bash
curl "https://registry.modelcontextprotocol.io/v0.1/servers/io.modelcontextprotocol.servers%2Fbrave-search/versions/latest"
```

## API Endpoints

- `GET /v0.1/servers` - List/search servers
- `GET /v0.1/servers/{serverName}/versions` - Get all versions
- `GET /v0.1/servers/{serverName}/versions/{version}` - Get specific version

## Query Parameters

- `search` - Substring search in server names
- `limit` - Results per page (1-100, default: 30)
- `cursor` - Pagination cursor
- `version` - Filter by version (use "latest")
- `updated_since` - Filter by update timestamp

## Registry URL

https://registry.modelcontextprotocol.io
