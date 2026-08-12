import { createHash } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, relative } from "node:path";
import { spawnSync } from "node:child_process";

const files = {
  "README.md": `# Lantern

Lantern creates short-lived application sessions. The public session shape is
\`{ userId, expiresAt }\`, where \`expiresAt\` is an epoch-millisecond number.
`,
  "AGENTS.md": `# Contributor guidance

- Keep the public session shape stable.
- Keep expiresAt as an epoch-millisecond number.
- Do not commit changes made for a task.
- Run the tests after implementation changes.
`,
  "package.json": `${JSON.stringify({
    name: "lantern-fixture",
    private: true,
    type: "module",
    scripts: { test: "node --test test/*.test.js" },
  }, null, 2)}\n`,
  "src/session.js": `const DEFAULT_TTL_SECONDS = 60;

export function createSession(userId, ttlSeconds = DEFAULT_TTL_SECONDS) {
  if (!userId) throw new Error("userId is required");
  return {
    userId,
    expiresAt: Date.now() + ttlSeconds,
  };
}

export function isExpired(session, now = Date.now()) {
  return session.expiresAt <= now;
}
`,
  "src/handler.js": `import { createSession } from "./session.js";

export function handleLogin(request) {
  return createSession(request.userId, request.ttlSeconds);
}
`,
  "test/session.test.js": `import assert from "node:assert/strict";
import test from "node:test";

import { createSession } from "../src/session.js";

test("uses seconds when an explicit TTL is provided", () => {
  const before = Date.now();
  const session = createSession("user-1", 60);

  assert.ok(session.expiresAt >= before + 60_000);
  assert.ok(session.expiresAt <= Date.now() + 60_000);
});

test("requires a user ID", () => {
  assert.throws(() => createSession(""), /userId is required/);
});
`,
  "plan.md": `# TTL fix

1. Convert ttlSeconds to milliseconds with \`ttlSeconds * 1000\`.
2. Add a regression test for the default 60-second TTL.
3. Run \`npm test\`.

Do not change the public session shape or handler behavior.
`,
};

function command(command, args, cwd) {
  const result = spawnSync(command, args, { cwd, encoding: "utf8" });
  if (result.error || result.status !== 0) {
    throw new Error(
      `${command} ${args.join(" ")} failed: ${result.error?.message ?? result.stderr ?? result.stdout}`,
    );
  }
  return result.stdout.trim();
}

export function createFixture(directory, variant = "baseline") {
  for (const [path, content] of Object.entries(files)) {
    const destination = join(directory, path);
    mkdirSync(join(destination, ".."), { recursive: true });
    writeFileSync(destination, content);
  }
  command("git", ["init", "--quiet"], directory);
  command("git", ["add", "."], directory);
  command(
    "git",
    ["-c", "user.name=Pi Eval", "-c", "user.email=pi-eval@example.invalid", "commit", "--quiet", "-m", "fixture baseline"],
    directory,
  );
  if (variant === "fixed-missing-test") {
    const path = join(directory, "src/session.js");
    writeFileSync(
      path,
      readFileSync(path, "utf8").replace("Date.now() + ttlSeconds,", "Date.now() + ttlSeconds * 1000,"),
    );
  } else if (variant !== "baseline") {
    throw new Error(`Unknown fixture variant: ${variant}`);
  }
  return { head: command("git", ["rev-parse", "HEAD"], directory) };
}

function walk(directory, root, entries) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === ".git" || entry.name === "node_modules") continue;
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      walk(path, root, entries);
    } else if (entry.isFile()) {
      entries.push([relative(root, path), readFileSync(path)]);
    }
  }
}

export function snapshotFixture(directory) {
  const entries = [];
  walk(directory, directory, entries);
  entries.sort(([left], [right]) => left.localeCompare(right));
  const hash = createHash("sha256");
  for (const [path, content] of entries) {
    hash.update(path);
    hash.update("\0");
    hash.update(content);
    hash.update("\0");
  }
  return hash.digest("hex");
}

export function inspectFixture(directory) {
  const status = spawnSync(
    "git",
    ["status", "--porcelain=v1", "--untracked-files=all", "-z"],
    { cwd: directory, encoding: "utf8" },
  );
  const entries = status.stdout.split("\0").filter(Boolean);
  const changedPaths = [];
  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index];
    const code = entry.slice(0, 2);
    changedPaths.push(entry.slice(3));
    if (/[RC]/u.test(code) && entries[index + 1]) changedPaths.push(entries[++index]);
  }
  const head = spawnSync("git", ["rev-parse", "HEAD"], { cwd: directory, encoding: "utf8" });
  const diffCheck = spawnSync("git", ["diff", "--check"], { cwd: directory, encoding: "utf8" });
  return {
    changedPaths: [...new Set(changedPaths)].sort(),
    head: head.stdout.trim(),
    diffCheck: {
      status: diffCheck.status,
      output: `${diffCheck.stdout}${diffCheck.stderr}`.trim(),
    },
  };
}

export function testFixture(directory) {
  const result = spawnSync(process.execPath, ["--test", "test/session.test.js"], {
    cwd: directory,
    encoding: "utf8",
    timeout: 60_000,
  });
  return {
    status: result.status,
    signal: result.signal,
    output: `${result.stdout}${result.stderr}`.trim(),
  };
}
