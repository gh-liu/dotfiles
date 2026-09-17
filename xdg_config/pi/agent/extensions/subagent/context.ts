import { existsSync, readFileSync, realpathSync } from "node:fs";
import { dirname, join, parse, relative } from "node:path";

const MAX_GUIDANCE_CHARACTERS = 32_000;
const MAX_GUIDANCE_FILE_CHARACTERS = 8_000;
const MAX_GUIDANCE_FILE_LINES = 200;
const TRUNCATION_MARKER = "\n[truncated]";

function isWithin(root: string, candidate: string): boolean {
  const path = relative(root, candidate);
  return path === "" || (!path.startsWith("..") && !parse(path).root);
}

export function canonicalCwd(allowedRoot: string, cwd: string): string {
  const canonicalRoot = realpathSync.native(allowedRoot);
  const canonical = realpathSync.native(cwd);
  if (!isWithin(canonicalRoot, canonical)) {
    throw new Error("Child working directory resolves outside the allowed project root.");
  }
  return canonical;
}

function boundGuidance(content: string): string {
  const lines = content.split(/\r?\n/u).slice(0, MAX_GUIDANCE_FILE_LINES);
  let bounded = lines.join("\n");
  const truncatedByLines = content.split(/\r?\n/u).length > MAX_GUIDANCE_FILE_LINES;
  if (bounded.length > MAX_GUIDANCE_FILE_CHARACTERS - TRUNCATION_MARKER.length) {
    bounded = bounded.slice(0, MAX_GUIDANCE_FILE_CHARACTERS - TRUNCATION_MARKER.length);
    return `${bounded}${TRUNCATION_MARKER}`;
  }
  return truncatedByLines ? `${bounded}${TRUNCATION_MARKER}` : bounded;
}

export function loadApplicableGuidance(cwd: string): string[] {
  const directories: string[] = [];
  let cursor = cwd;
  while (true) {
    directories.push(cursor);
    const parent = dirname(cursor);
    if (parent === cursor) break;
    cursor = parent;
  }

  const result: string[] = [];
  let remaining = MAX_GUIDANCE_CHARACTERS;
  for (const directory of directories.reverse()) {
    const path = join(directory, "AGENTS.md");
    if (!existsSync(path)) continue;
    const entry = `Guidance from ${path}:\n${boundGuidance(readFileSync(path, "utf8"))}`;
    if (entry.length <= remaining) {
      result.push(entry);
      remaining -= entry.length;
      continue;
    }
    if (remaining > TRUNCATION_MARKER.length) {
      result.push(`${entry.slice(0, remaining - TRUNCATION_MARKER.length)}${TRUNCATION_MARKER}`);
    }
    break;
  }
  return result;
}
