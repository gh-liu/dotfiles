import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { parseFrontmatter } from "@earendil-works/pi-coding-agent";
import type { SubagentExecutionProfile } from "./protocol.ts";

const ALLOWED_TOOLS = new Set([
  "read",
  "grep",
  "find",
  "ls",
  "web_search",
  "edit",
  "write",
  "bash",
]);
const THINKING_LEVELS = new Set(["off", "minimal", "low", "medium", "high", "xhigh", "max"]);

export interface ParsedAgentDefinition extends SubagentExecutionProfile {
  description: string;
  contextPolicy: "fresh";
  maxDepth: 1;
}

export interface AgentDefinition extends ParsedAgentDefinition {
  filePath: string;
}

export interface AgentDefinitionError {
  filePath: string;
  error: string;
}

export interface AgentDiscovery {
  agents: AgentDefinition[];
  errors: AgentDefinitionError[];
}

function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${field} must be a non-empty string`);
  }
  return value.trim();
}

function optionalString(value: unknown, field: string): string | undefined {
  return value === undefined ? undefined : requireString(value, field);
}

function stringArray(value: unknown, field: string): string[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error(`${field} must be a non-empty string array`);
  }
  return value.map((item) => requireString(item, field));
}

export function parseAgentDefinition(content: string): ParsedAgentDefinition {
  const { frontmatter, body } = parseFrontmatter<Record<string, unknown>>(content);
  const name = requireString(frontmatter.name, "name");
  if (!/^[a-z][a-z0-9-]*$/.test(name)) {
    throw new Error("name must be a canonical lowercase kebab-case identifier");
  }

  const tools = stringArray(frontmatter.tools, "tools");
  const unsupportedTools = tools.filter((tool) => !ALLOWED_TOOLS.has(tool));
  if (unsupportedTools.length > 0) {
    throw new Error(`unsupported subagent tools: ${unsupportedTools.join(", ")}`);
  }
  if (new Set(tools).size !== tools.length) {
    throw new Error("tools must not contain duplicates");
  }
  if (frontmatter.extensions !== undefined) {
    throw new Error("subagents do not enable executable extensions");
  }
  if (frontmatter.fallbackModels !== undefined) {
    throw new Error("subagents do not support model fallbacks");
  }
  if (frontmatter.contextPolicy !== undefined && frontmatter.contextPolicy !== "fresh") {
    throw new Error("subagents support only contextPolicy: fresh");
  }
  if (frontmatter.maxDepth !== undefined && frontmatter.maxDepth !== 1) {
    throw new Error("subagents require maxDepth: 1");
  }

  const thinking = optionalString(frontmatter.thinking, "thinking");
  if (thinking && !THINKING_LEVELS.has(thinking)) {
    throw new Error(`unsupported thinking level: ${thinking}`);
  }
  const systemPrompt = body.trim();
  if (systemPrompt === "") {
    throw new Error("system prompt must not be empty");
  }

  return {
    name,
    description: requireString(frontmatter.description, "description"),
    systemPrompt,
    model: optionalString(frontmatter.model, "model"),
    thinking,
    tools,
    contextPolicy: "fresh",
    maxDepth: 1,
  };
}

export function loadAgentDefinition(filePath: string): AgentDefinition {
  try {
    return {
      ...parseAgentDefinition(readFileSync(filePath, "utf8")),
      filePath,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`${filePath}: ${message}`);
  }
}

export function discoverUserAgents(directory: string): AgentDiscovery {
  if (!existsSync(directory)) return { agents: [], errors: [] };

  const agents: AgentDefinition[] = [];
  const errors: AgentDefinitionError[] = [];
  const names = new Set<string>();
  const entries = readdirSync(directory, { withFileTypes: true })
    .filter((entry) => entry.name.endsWith(".md") && (entry.isFile() || entry.isSymbolicLink()))
    .sort((left, right) => left.name.localeCompare(right.name));

  for (const entry of entries) {
    const filePath = join(directory, entry.name);
    try {
      const agent = loadAgentDefinition(filePath);
      if (names.has(agent.name)) {
        throw new Error(`${filePath}: duplicate agent name: ${agent.name}`);
      }
      names.add(agent.name);
      agents.push(agent);
    } catch (error) {
      errors.push({ filePath, error: error instanceof Error ? error.message : String(error) });
    }
  }

  return { agents, errors };
}
