import { existsSync, readdirSync, readFileSync, realpathSync } from "node:fs";
import { isAbsolute, join, relative } from "node:path";

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

type AgentOverride = Pick<AgentDefinition, "model" | "thinking" | "description">;

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

export function applyAgentOverrides(discovery: AgentDiscovery, overrides: unknown): AgentDiscovery {
  if (overrides === undefined || overrides === null) return discovery;
  if (typeof overrides !== "object" || Array.isArray(overrides)) return discovery;

  const agents = discovery.agents.map((agent) => ({ ...agent }));
  const errors = [...discovery.errors];
  const byName = new Map(agents.map((agent) => [agent.name, agent]));

  for (const [name, rawOverride] of Object.entries(overrides)) {
    const filePath = `settings.json:${name}`;
    const agent = byName.get(name);
    if (!agent) {
      errors.push({ filePath, error: `${filePath}: unknown agent override: ${name}` });
      continue;
    }
    if (typeof rawOverride !== "object" || rawOverride === null || Array.isArray(rawOverride)) {
      errors.push({ filePath, error: `${filePath}: override must be an object` });
      continue;
    }

    const override = rawOverride as Record<string, unknown>;
    const validated: Partial<AgentOverride> = {};
    for (const field of ["model", "thinking", "description"] as const) {
      if (override[field] === undefined) continue;
      try {
        const value = requireString(override[field], field);
        if (field === "thinking" && !THINKING_LEVELS.has(value)) {
          throw new Error(`unsupported thinking level: ${value}`);
        }
        validated[field] = value;
      } catch (error) {
        errors.push({ filePath, error: `${filePath}: ${error instanceof Error ? error.message : String(error)}` });
      }
    }
    Object.assign(agent, validated);
  }

  return { agents, errors };
}

export function discoverUserAgents(directory: string): AgentDiscovery {
  if (!existsSync(directory)) return { agents: [], errors: [] };

  const agents: AgentDefinition[] = [];
  const errors: AgentDefinitionError[] = [];
  const names = new Set<string>();
  const canonicalDirectory = realpathSync(directory);
  const entries = readdirSync(directory, { withFileTypes: true })
    .filter((entry) => entry.name.endsWith(".md") && (entry.isFile() || entry.isSymbolicLink()))
    .sort((left, right) => left.name.localeCompare(right.name));

  for (const entry of entries) {
    const filePath = join(directory, entry.name);
    try {
      const canonicalFile = realpathSync(filePath);
      const relativeFile = relative(canonicalDirectory, canonicalFile);
      if (relativeFile === ".." || relativeFile.startsWith(`..${process.platform === "win32" ? "\\" : "/"}`) || isAbsolute(relativeFile)) {
        throw new Error(`${filePath}: agent definition symlink resolves outside the agent directory`);
      }
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

/**
 * Loads `subagents[agent]` overrides from settings.json. Missing files are not
 * errors; malformed JSON surfaces as a single collected error.
 */
export function loadSubagentOverrides(settingsPath: string): { overrides?: unknown; errors: AgentDefinitionError[] } {
  try {
    const settings = JSON.parse(readFileSync(settingsPath, "utf8")) as unknown;
    if (typeof settings !== "object" || settings === null || Array.isArray(settings)) return { errors: [] };
    const subagents = (settings as Record<string, unknown>).subagents;
    if (subagents === undefined || subagents === null || typeof subagents !== "object" || Array.isArray(subagents)) {
      return { errors: [] };
    }
    return { overrides: subagents, errors: [] };
  } catch (error) {
    if (error && typeof error === "object" && "code" in error && (error as { code?: unknown }).code === "ENOENT") {
      return { errors: [] };
    }
    return {
      errors: [{
        filePath: "settings.json:subagents",
        error: `settings.json:subagents: ${error instanceof Error ? error.message : String(error)}`,
      }],
    };
  }
}

export interface SettingsDefaults {
  defaultProvider?: string;
  defaultModel?: string;
}

/**
 * Reads the top-level default provider/model from settings.json. Resolved at
 * spawn time as the last resort by resolveAgentModel, after the agent's
 * explicit model and the parent session's current model. Missing files and
 * malformed values yield empty defaults rather than surfaced errors
 * (overrides already own the error path).
 */
export function loadSettingsDefaults(settingsPath: string): SettingsDefaults {
  try {
    const settings = JSON.parse(readFileSync(settingsPath, "utf8")) as unknown;
    if (typeof settings !== "object" || settings === null || Array.isArray(settings)) return {};
    const provider = (settings as Record<string, unknown>).defaultProvider;
    const model = (settings as Record<string, unknown>).defaultModel;
    return {
      ...(typeof provider === "string" && provider.trim() !== "" ? { defaultProvider: provider.trim() } : {}),
      ...(typeof model === "string" && model.trim() !== "" ? { defaultModel: model.trim() } : {}),
    };
  } catch {
    return {};
  }
}

/**
 * Resolves the runtime model for an agent at spawn time. An explicit model
 * (frontmatter or a `subagents[agent]` settings override) wins, then the
 * parent session's current model, then the top-level settings defaults.
 * Returns undefined when none apply, leaving the agent's model unset.
 */
export function resolveAgentModel(
  agent: AgentDefinition,
  defaults: SettingsDefaults,
  mainModel?: string,
): string | undefined {
  if (agent.model) return agent.model;
  if (mainModel) return mainModel;
  if (defaults.defaultProvider && defaults.defaultModel) {
    return `${defaults.defaultProvider}/${defaults.defaultModel}`;
  }
  return undefined;
}

/** Renders the bounded one-line-per-agent catalog shown in the tool description. */
export function formatAgentCatalog(discovery: AgentDiscovery): string {
  const agents = discovery.agents.length === 0
    ? ["none"]
    : discovery.agents.map((agent) => `${agent.name}: ${agent.description.replace(/\s+/g, " ").trim()}`);
  const invalid = discovery.errors.length === 0
    ? []
    : ["", "Invalid agent definitions:", ...discovery.errors.map((error) => `- ${error.error}`)];
  return [...agents, ...invalid].join("\n");
}
