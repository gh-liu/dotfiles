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
export const THINKING_LEVELS = new Set(["off", "minimal", "low", "medium", "high", "xhigh", "max"]);

export interface AgentOverride {
  model?: string;
  thinking?: string;
  description?: string;
}

function normalizeStringField(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed === "" ? undefined : trimmed;
}

function extractRawOverrides(settings: unknown): Record<string, unknown> {
  if (!settings || typeof settings !== "object" || Array.isArray(settings)) return {};
  const sub = (settings as Record<string, unknown>).subagents;
  if (!sub || typeof sub !== "object" || Array.isArray(sub)) return {};
  return sub as Record<string, unknown>;
}

export function extractAgentOverrides(settings: unknown): Record<string, AgentOverride> {
  const raw = extractRawOverrides(settings);
  const result: Record<string, AgentOverride> = {};
  for (const [name, value] of Object.entries(raw)) {
    if (!value || typeof value !== "object" || Array.isArray(value)) continue;
    const v = value as Record<string, unknown>;
    const ov: AgentOverride = {};
    const model = normalizeStringField(v.model);
    if (model !== undefined) ov.model = model;
    const thinkingRaw = normalizeStringField(v.thinking);
    if (thinkingRaw !== undefined) {
      if (THINKING_LEVELS.has(thinkingRaw)) ov.thinking = thinkingRaw;
      else {
        console.warn(`[subagent] ignoring invalid thinking override for ${name}: ${thinkingRaw}`);
      }
    }
    const description = normalizeStringField(v.description);
    if (description !== undefined) ov.description = description;
    if (Object.keys(ov).length > 0) result[name] = ov;
  }
  return result;
}

export function applyAgentOverrides(discovery: AgentDiscovery, settings: unknown): AgentDiscovery {
  const raw = extractRawOverrides(settings);
  const extraErrors: AgentDefinitionError[] = [];
  const overrides: Record<string, AgentOverride> = {};
  for (const [name, value] of Object.entries(raw)) {
    if (!value || typeof value !== "object" || Array.isArray(value)) continue;
    const v = value as Record<string, unknown>;
    const ov: AgentOverride = {};
    let hasValid = false;
    const model = normalizeStringField(v.model);
    if (model !== undefined) { ov.model = model; hasValid = true; }
    else if (v.model !== undefined && typeof v.model === "string" && v.model.trim() === "") {
      // empty string -> treat as not set, no warning
    }
    const thinkingRaw = v.thinking as unknown;
    if (thinkingRaw !== undefined) {
      const thinking = normalizeStringField(thinkingRaw);
      if (thinking !== undefined) {
        if (THINKING_LEVELS.has(thinking)) { ov.thinking = thinking; hasValid = true; }
        else {
          console.warn(`[subagent] ignoring invalid thinking override for ${name}: ${thinking}`);
          extraErrors.push({
            filePath: "<settings.json>",
            error: `invalid thinking override for ${name}: ${thinking} – ignored`,
          });
        }
      }
    }
    const description = normalizeStringField(v.description);
    if (description !== undefined) { ov.description = description; hasValid = true; }
    if (hasValid) overrides[name] = ov;
  }
  if (Object.keys(overrides).length === 0 && extraErrors.length === 0) return discovery;
  const agents = discovery.agents.map((agent) => {
    const ov = overrides[agent.name];
    if (!ov) return agent;
    return {
      ...agent,
      ...(ov.model !== undefined ? { model: ov.model } : {}),
      ...(ov.thinking !== undefined ? { thinking: ov.thinking } : {}),
      ...(ov.description !== undefined ? { description: ov.description } : {}),
    };
  });
  return { agents, errors: [...discovery.errors, ...extraErrors] };
}

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
