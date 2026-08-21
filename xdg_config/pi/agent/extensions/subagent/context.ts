import { execFileSync } from "node:child_process";
import { closeSync, existsSync, fstatSync, openSync, readSync, realpathSync, statSync } from "node:fs";
import { isAbsolute, join, relative, resolve, sep } from "node:path";

import { boundText } from "./output.ts";
import type { SubagentWorkOrder } from "./protocol.ts";

const MAX_GUIDANCE_CHARACTERS = 32_000;
const MAX_GUIDANCE_LINES = 400;
const MAX_GUIDANCE_FILE_BYTES = MAX_GUIDANCE_CHARACTERS * 4;
const FILE_TRUNCATION_MARKER = "\n[truncated while reading guidance file]";
const GUIDANCE_OMISSION_MARKER = "[truncated: additional project guidance omitted]";

function isWithin(root: string, candidate: string): boolean {
  const path = relative(root, candidate);
  return path === "" || (!path.startsWith(`..${sep}`) && path !== ".." && !isAbsolute(path));
}

export function findAllowedRoot(parentCwd: string): string {
  const canonicalParent = realpathSync.native(parentCwd);
  try {
    const gitRoot = execFileSync("git", ["rev-parse", "--show-toplevel"], {
      cwd: canonicalParent,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    return realpathSync.native(gitRoot);
  } catch {
    return canonicalParent;
  }
}

export function resolveChildCwd(allowedRoot: string, requestedCwd: string): string {
  const canonicalRoot = realpathSync.native(allowedRoot);
  const candidate = realpathSync.native(resolve(canonicalRoot, requestedCwd));
  if (!isWithin(canonicalRoot, candidate)) {
    throw new Error(`Child cwd is outside the allowed root: ${candidate}`);
  }
  return candidate;
}

function readGuidanceFile(filePath: string): string {
  const descriptor = openSync(filePath, "r");
  try {
    if (!fstatSync(descriptor).isFile()) throw new Error(`Project guidance is not a file: ${filePath}`);
    const buffer = Buffer.allocUnsafe(MAX_GUIDANCE_FILE_BYTES + 1);
    let offset = 0;
    while (offset < buffer.byteLength) {
      const bytesRead = readSync(descriptor, buffer, offset, buffer.byteLength - offset, null);
      if (bytesRead === 0) break;
      offset += bytesRead;
    }
    const truncated = offset > MAX_GUIDANCE_FILE_BYTES;
    const content = buffer.subarray(0, Math.min(offset, MAX_GUIDANCE_FILE_BYTES)).toString("utf8");
    return truncated ? `${content}${FILE_TRUNCATION_MARKER}` : content;
  } finally {
    closeSync(descriptor);
  }
}

export function loadProjectGuidance(allowedRoot: string, childCwd: string): string[] {
  const root = realpathSync.native(allowedRoot);
  const child = realpathSync.native(childCwd);
  if (!isWithin(root, child)) throw new Error(`Child cwd is outside the allowed root: ${child}`);

  const relativeChild = relative(root, child);
  const segments = relativeChild === "" ? [] : relativeChild.split(sep);
  const directories = [root];
  let current = root;
  for (const segment of segments) {
    current = join(current, segment);
    directories.push(current);
  }

  const guidanceFiles = directories
    .map((directory) => join(directory, "AGENTS.md"))
    .filter((filePath) => {
      if (!existsSync(filePath)) return false;
      const canonicalFile = realpathSync.native(filePath);
      return isWithin(root, canonicalFile) && statSync(canonicalFile).isFile();
    });
  const guidance: string[] = [];
  let remainingCharacters = MAX_GUIDANCE_CHARACTERS;
  let remainingLines = MAX_GUIDANCE_LINES;
  for (const [index, filePath] of guidanceFiles.entries()) {
    const hasLaterFiles = index < guidanceFiles.length - 1;
    const reservedCharacters = hasLaterFiles ? GUIDANCE_OMISSION_MARKER.length : 0;
    const reservedLines = hasLaterFiles ? 1 : 0;
    if (remainingCharacters <= reservedCharacters || remainingLines <= reservedLines) {
      guidance.push(GUIDANCE_OMISSION_MARKER.slice(0, remainingCharacters));
      break;
    }
    const canonicalFile = realpathSync.native(filePath);
    const content = boundText(`Guidance from ${filePath}:\n${readGuidanceFile(canonicalFile)}`, {
      maxCharacters: remainingCharacters - reservedCharacters,
      maxLines: remainingLines - reservedLines,
    });
    guidance.push(content);
    remainingCharacters -= content.length;
    remainingLines -= content.split("\n").length;
    if (hasLaterFiles && (remainingCharacters <= reservedCharacters || remainingLines <= reservedLines)) {
      guidance.push(GUIDANCE_OMISSION_MARKER.slice(0, remainingCharacters));
      break;
    }
  }
  return guidance;
}

/** Materializes the delegated work-order envelope from context materials. */
export function createWorkOrder(task: string, cwd: string, projectGuidance: string[]): SubagentWorkOrder {
  return {
    goal: task,
    scope: [cwd],
    constraints: [
      "Use only the tools declared by the selected agent.",
      "Preserve unrelated existing changes and do not perform destructive shared actions.",
      "Do not delegate to another agent.",
    ],
    knownDecisions: [],
    evidence: [],
    validation: [],
    returnFormat:
      "Return a concise result with completed work or findings, evidence, validation, blockers, and residual risks.",
    projectGuidance,
  };
}
