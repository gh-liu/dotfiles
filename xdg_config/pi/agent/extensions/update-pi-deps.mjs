#!/usr/bin/env node
/**
 * Update pinned @earendil-works/pi-* dependencies across all extension packages.
 *
 * Usage:
 *   ./update-pi-deps.mjs                  # Resolve latest version from npm
 *   ./update-pi-deps.mjs 1.6.0            # Pin an explicit version
 *   ./update-pi-deps.mjs --from-pi        # Match locally installed `pi --version`
 *   ./update-pi-deps.mjs --dry-run        # Preview changes without writing or installing
 *   ./update-pi-deps.mjs --no-test        # Skip `npm test` after updating
 */

import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const EXTENSIONS_DIR = dirname(fileURLToPath(import.meta.url));
const PI_PKG_PREFIX = "@earendil-works/pi-";
const SEMVER_RE = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/;
const README_PIN_RE = /(The packages pin\s+Pi )\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?( for development\.)/;

function printUsage() {
  console.log(`Usage: update-pi-deps.mjs [version] [options]

Options:
  --from-pi    Use version reported by \`pi --version\`
  --dry-run    Show planned changes without editing files or running npm
  --no-test    Skip \`npm test\` in each extension package
  -h, --help   Show this help message`);
}

function parseArgs(argv) {
  let version;
  let fromPi = false;
  let dryRun = false;
  let runTests = true;

  for (const arg of argv) {
    if (arg === "-h" || arg === "--help") {
      printUsage();
      process.exit(0);
    } else if (arg === "--from-pi") {
      fromPi = true;
    } else if (arg === "--dry-run") {
      dryRun = true;
    } else if (arg === "--no-test") {
      runTests = false;
    } else if (arg.startsWith("-")) {
      throw new Error(`Unknown option: ${arg}`);
    } else if (version === undefined) {
      version = arg;
    } else {
      throw new Error(`Unexpected argument: ${arg}`);
    }
  }

  if (fromPi && version !== undefined) {
    throw new Error("Specify either an explicit version or --from-pi, not both.");
  }
  return { version, fromPi, dryRun, runTests };
}

function runCommand(cmd, args, options = {}) {
  return execFileSync(cmd, args, {
    encoding: "utf8",
    stdio: options.capture ? ["ignore", "pipe", "pipe"] : "inherit",
    cwd: options.cwd,
  });
}

function resolveTargetVersion({ version, fromPi }) {
  let resolved;
  if (version !== undefined) {
    resolved = version.trim();
  } else if (fromPi) {
    resolved = runCommand("pi", ["--version"], { capture: true }).trim();
  } else {
    resolved = runCommand("npm", ["view", "@earendil-works/pi-coding-agent", "version"], {
      capture: true,
    }).trim();
  }

  if (!SEMVER_RE.test(resolved)) {
    throw new Error(`Invalid Pi version "${resolved}"`);
  }
  return resolved;
}

function resolveTypeboxVersion(targetVersion) {
  try {
    const raw = runCommand(
      "npm",
      ["view", `@earendil-works/pi-coding-agent@${targetVersion}`, "dependencies.typebox"],
      { capture: true },
    ).trim();
    return SEMVER_RE.test(raw) ? raw : undefined;
  } catch {
    return undefined;
  }
}

function discoverExtensionPackages(dir) {
  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
    .map((entry) => ({
      name: entry.name,
      dir: join(dir, entry.name),
      manifestPath: join(dir, entry.name, "package.json"),
    }))
    .filter((pkg) => existsSync(pkg.manifestPath))
    .sort((a, b) => a.name.localeCompare(b.name));
}

function updateManifest(manifestPath, targetVersion, typeboxVersion, dryRun) {
  const original = readFileSync(manifestPath, "utf8");
  const pkg = JSON.parse(original);
  const updates = [];

  for (const section of ["dependencies", "devDependencies"]) {
    const deps = pkg[section];
    if (!deps || typeof deps !== "object") continue;
    for (const [name, current] of Object.entries(deps)) {
      if (name.startsWith(PI_PKG_PREFIX) && current !== targetVersion) {
        deps[name] = targetVersion;
        updates.push(`${section}.${name}: ${current} -> ${targetVersion}`);
      } else if (name === "typebox" && typeboxVersion && current !== typeboxVersion) {
        deps[name] = typeboxVersion;
        updates.push(`${section}.${name}: ${current} -> ${typeboxVersion}`);
      }
    }
  }

  if (updates.length > 0 && !dryRun) {
    writeFileSync(manifestPath, `${JSON.stringify(pkg, null, 2)}\n`, "utf8");
  }
  return { updates, hasTestScript: Boolean(pkg.scripts?.test) };
}

function updateReadme(targetVersion, dryRun) {
  const readmePath = join(EXTENSIONS_DIR, "README.md");
  if (!existsSync(readmePath)) return false;
  const original = readFileSync(readmePath, "utf8");
  const updated = original.replace(README_PIN_RE, `$1${targetVersion}$2`);
  if (updated === original) return false;
  if (!dryRun) writeFileSync(readmePath, updated, "utf8");
  return true;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const targetVersion = resolveTargetVersion(opts);
  const typeboxVersion = resolveTypeboxVersion(targetVersion);
  const packages = discoverExtensionPackages(EXTENSIONS_DIR);

  if (packages.length === 0) {
    console.log("No extension packages found.");
    return;
  }

  console.log(
    `Target Pi version: ${targetVersion}${typeboxVersion ? ` (typebox ${typeboxVersion})` : ""}${opts.dryRun ? " (dry-run)" : ""}`,
  );

  const results = [];
  for (const pkg of packages) {
    const { updates, hasTestScript } = updateManifest(
      pkg.manifestPath,
      targetVersion,
      typeboxVersion,
      opts.dryRun,
    );
    if (updates.length === 0) {
      console.log(`\n[${pkg.name}] already at ${targetVersion}`);
    } else {
      console.log(`\n[${pkg.name}] ${opts.dryRun ? "would update" : "updating"}:`);
      for (const line of updates) console.log(`  - ${line}`);
      if (!opts.dryRun) {
        runCommand("npm", ["install"], { cwd: pkg.dir });
      }
    }

    let testStatus = "skipped";
    if (!opts.dryRun && opts.runTests && hasTestScript) {
      try {
        runCommand("npm", ["test"], { cwd: pkg.dir });
        testStatus = "passed";
      } catch {
        testStatus = "failed";
      }
    }
    results.push({ name: pkg.name, updated: updates.length > 0, testStatus });
  }

  const readmeChanged = updateReadme(targetVersion, opts.dryRun);
  if (readmeChanged) {
    console.log(`\n[README.md] ${opts.dryRun ? "would update" : "updated"} pinned Pi version to ${targetVersion}`);
  }

  console.log("\nSummary:");
  for (const row of results) {
    const state = row.updated ? (opts.dryRun ? "would-update" : "updated") : "unchanged";
    console.log(`  - ${row.name}: ${state}, test=${row.testStatus}`);
  }

  if (results.some((row) => row.testStatus === "failed")) {
    process.exitCode = 1;
  }
}

try {
  main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}
