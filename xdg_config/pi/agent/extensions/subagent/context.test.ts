import { afterEach, describe, expect, test } from "vitest";
import { existsSync, mkdtempSync, mkdirSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { loadProjectGuidance, resolveChildCwd } from "./context.ts";

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function temporaryDirectory(prefix: string): string {
  const directory = mkdtempSync(join(tmpdir(), prefix));
  temporaryDirectories.push(directory);
  return directory;
}

describe("child execution context", () => {
  test("canonicalizes a cwd inside the allowed root", () => {
    const root = temporaryDirectory("pi-subagent-root-");
    const nested = join(root, "packages", "api");
    mkdirSync(nested, { recursive: true });

    expect(resolveChildCwd(root, nested)).toBe(realpathSync(nested));
  });

  test("uses native canonical casing on a case-insensitive filesystem", () => {
    const root = temporaryDirectory("pi-subagent-case-root-");
    const nested = join(root, "packages", "api");
    mkdirSync(nested, { recursive: true });
    const differentlyCased = nested.replace(/api$/u, "API");

    if (existsSync(differentlyCased)) {
      expect(resolveChildCwd(root, differentlyCased)).toBe(realpathSync.native(nested));
    } else {
      expect(resolveChildCwd(root, nested)).toBe(realpathSync.native(nested));
    }
  });

  test("rejects lexical and symlink escapes", () => {
    const root = temporaryDirectory("pi-subagent-root-");
    const outside = temporaryDirectory("pi-subagent-outside-");
    symlinkSync(outside, join(root, "escape"));

    expect(() => resolveChildCwd(root, join(root, ".."))).toThrow("outside the allowed root");
    expect(() => resolveChildCwd(root, join(root, "escape"))).toThrow("outside the allowed root");
  });

  test("materializes applicable guidance from root to child cwd", () => {
    const root = temporaryDirectory("pi-subagent-root-");
    const child = join(root, "packages", "api");
    mkdirSync(child, { recursive: true });
    writeFileSync(join(root, "AGENTS.md"), "Root rules [truncated]");
    writeFileSync(join(root, "packages", "AGENTS.md"), "Package rules");
    writeFileSync(join(child, "AGENTS.md"), "API rules");

    const canonicalRoot = realpathSync(root);
    const canonicalChild = realpathSync(child);
    expect(loadProjectGuidance(root, child)).toEqual([
      `Guidance from ${join(canonicalRoot, "AGENTS.md")}:\nRoot rules [truncated]`,
      `Guidance from ${join(canonicalRoot, "packages", "AGENTS.md")}:\nPackage rules`,
      `Guidance from ${join(canonicalChild, "AGENTS.md")}:\nAPI rules`,
    ]);
  });

  test("bounds individual and aggregate project guidance", () => {
    const root = temporaryDirectory("pi-subagent-root-");
    const child = join(root, "packages", "api");
    mkdirSync(child, { recursive: true });
    writeFileSync(join(root, "AGENTS.md"), "root-line\n".repeat(50_000));
    writeFileSync(join(root, "packages", "AGENTS.md"), "package-line\n".repeat(50_000));
    writeFileSync(join(child, "AGENTS.md"), "api-line\n".repeat(50_000));

    const guidance = loadProjectGuidance(root, child);
    const combined = guidance.join("");

    expect(combined.length).toBeLessThanOrEqual(32_000);
    expect(guidance.flatMap((entry) => entry.split("\n"))).toHaveLength(400);
    expect(combined).toContain("[truncated]");
  });
});
