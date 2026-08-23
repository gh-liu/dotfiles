#!/usr/bin/env node

import { createHash } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  aggregateResults,
  analyzeJsonl,
  compareSummaries,
  evaluateExpectation,
  evaluateExpectedSubagentErrors,
} from "./analyze.mjs";
import {
  createFixture,
  inspectFixture,
  snapshotFixture,
  testFixture,
} from "./fixture.mjs";
import { scenarios } from "./scenarios.mjs";

const evalDirectory = dirname(fileURLToPath(import.meta.url));
const extensionsRoot = resolve(evalDirectory, "../..");
const agentRoot = resolve(evalDirectory, "../../..");
const xdgConfigRoot = resolve(agentRoot, "../..");
const activeChildren = new Set();

const usage = `Usage: {node|bun} subagent/eval/run.mjs [options]

Modes:
  --full                 Run all scenarios with their statistical repeat counts (default)
  --quick                Run the six core scenarios once; routing misses are warnings

Selection and execution:
  --scenario <id[,id]>   Run only selected scenarios (repeatable)
  --repeat <n>           Override every selected scenario's repeat count
  --model <provider/id>  Parent Pi model (default: openai-codex/gpt-5.6-luna)
  --subagent-model <id>  Override every child model in the isolated eval config
  --subagent-thinking <level>  Override child thinking in the isolated eval config
  --thinking <level>     Parent Pi thinking level: off, minimal, low, medium, high, xhigh, max
  --jobs <n>             Concurrent isolated Pi processes (default: 1)
  --timeout <seconds>    Timeout per Pi process (default: 300)

Reports and exit policy:
  --report <directory>   Artifact directory (default: a new /tmp directory)
  --baseline <path>      Previous report.json or its containing directory
  --strict               Fail when a behavioral threshold is missed
  --no-strict            Warn instead (default only in quick mode)
  --keep                 Keep temporary fixture repositories
  --dry-run              Print the execution plan without provider calls
  --help                  Show this help
`;

function parseArguments(argv) {
  const options = {
    mode: "full",
    scenarioIds: [],
    repeat: null,
    model: process.env.PI_SUBAGENT_EVAL_MODEL ?? "openai-codex/gpt-5.6-luna",
    subagentModel: process.env.PI_SUBAGENT_EVAL_SUBAGENT_MODEL ?? null,
    subagentThinking: process.env.PI_SUBAGENT_EVAL_SUBAGENT_THINKING ?? null,
    thinking: null,
    jobs: 1,
    timeoutMs: 300_000,
    report: null,
    baseline: null,
    strict: null,
    keep: false,
    dryRun: false,
    help: false,
  };
  const value = (flag, index) => {
    const result = argv[index + 1];
    if (!result || result.startsWith("--")) throw new Error(`${flag} requires a value`);
    return result;
  };
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--full") options.mode = "full";
    else if (argument === "--quick") options.mode = "quick";
    else if (argument === "--scenario") {
      options.scenarioIds.push(...value(argument, index).split(",").filter(Boolean));
      index += 1;
    } else if (argument === "--repeat") {
      options.repeat = Number.parseInt(value(argument, index), 10);
      index += 1;
    } else if (argument === "--model") {
      options.model = value(argument, index);
      index += 1;
    } else if (argument === "--subagent-model") {
      options.subagentModel = value(argument, index);
      index += 1;
    } else if (argument === "--subagent-thinking") {
      options.subagentThinking = value(argument, index);
      index += 1;
    } else if (argument === "--thinking") {
      options.thinking = value(argument, index);
      index += 1;
    } else if (argument === "--jobs") {
      options.jobs = Number.parseInt(value(argument, index), 10);
      index += 1;
    } else if (argument === "--timeout") {
      options.timeoutMs = Number.parseFloat(value(argument, index)) * 1000;
      index += 1;
    } else if (argument === "--report") {
      options.report = resolve(value(argument, index));
      index += 1;
    } else if (argument === "--baseline") {
      options.baseline = resolve(value(argument, index));
      index += 1;
    } else if (argument === "--strict") options.strict = true;
    else if (argument === "--no-strict") options.strict = false;
    else if (argument === "--keep") options.keep = true;
    else if (argument === "--dry-run") options.dryRun = true;
    else if (argument === "--help" || argument === "-h") options.help = true;
    else throw new Error(`Unknown option: ${argument}`);
  }
  if (options.repeat !== null && (!Number.isInteger(options.repeat) || options.repeat < 1)) {
    throw new Error("--repeat must be a positive integer");
  }
  if (!Number.isInteger(options.jobs) || options.jobs < 1) {
    throw new Error("--jobs must be a positive integer");
  }
  if (!Number.isFinite(options.timeoutMs) || options.timeoutMs <= 0) {
    throw new Error("--timeout must be a positive number of seconds");
  }
  options.strict ??= options.mode === "full";
  return options;
}

function sync(command, args, cwd = extensionsRoot, env = process.env) {
  return spawnSync(command, args, { cwd, env, encoding: "utf8" });
}

function requireSuccess(result, label) {
  if (result.error || result.status !== 0) {
    throw new Error(`${label}: ${result.error?.message ?? result.stderr ?? result.stdout}`.trim());
  }
  return result.stdout.trim();
}

function preflight(options) {
  const version = requireSuccess(sync("pi", ["--version"]), "Pi is not available");
  requireSuccess(
    sync("pi", ["auth", "check", "--model", options.model], extensionsRoot, {
      ...process.env,
      PI_CODING_AGENT_DIR: options.piAgentDirectory,
      XDG_CONFIG_HOME: xdgConfigRoot,
    }),
    `Pi authentication is not ready for ${options.model}`,
  );
  return version;
}

function selectedScenarios(options) {
  let selected;
  if (options.scenarioIds.length > 0) {
    const requested = new Set(options.scenarioIds);
    const unknown = [...requested].filter((id) => !scenarios.some((scenario) => scenario.id === id));
    if (unknown.length > 0) throw new Error(`Unknown scenario(s): ${unknown.join(", ")}`);
    selected = scenarios.filter((scenario) => requested.has(scenario.id));
  } else {
    selected = options.mode === "quick" ? scenarios.filter((scenario) => scenario.quick) : scenarios;
  }
  if (selected.length === 0) throw new Error("No scenarios selected");
  return selected;
}

function executionPlan(options, selected) {
  const plan = [];
  for (const scenario of selected) {
    const repetitions = options.repeat ?? (options.mode === "quick" ? 1 : scenario.repeats);
    for (let repetition = 1; repetition <= repetitions; repetition += 1) {
      plan.push({ scenario, repetition, order: plan.length });
    }
  }
  return plan;
}

function createIsolatedAgentDirectory(runtimeDirectory) {
  const directory = join(runtimeDirectory, "agent-config");
  mkdirSync(directory);
  for (const name of ["agents", "extensions", "skills", "missions"]) {
    const source = join(agentRoot, name);
    if (existsSync(source)) {
      symlinkSync(source, join(directory, name), process.platform === "win32" ? "junction" : "dir");
    }
  }
  for (const name of [
    ".projections.json",
    "auth.json",
    "keybindings.json",
    "models-store.json",
    "models.json",
    "settings.json",
  ]) {
    const source = join(agentRoot, name);
    if (existsSync(source)) copyFileSync(source, join(directory, name));
  }
  return directory;
}

function overrideSubagents(directory, model, thinking) {
  if (!model && !thinking) return;
  const settingsPath = join(directory, "settings.json");
  const settings = existsSync(settingsPath) ? JSON.parse(readFileSync(settingsPath, "utf8")) : {};
  settings.subagents ??= {};
  const agentsDirectory = join(agentRoot, "agents");
  for (const entry of readdirSync(agentsDirectory, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
    const definition = readFileSync(join(agentsDirectory, entry.name), "utf8");
    const name = definition.match(/^name:\s*([^\s]+)\s*$/mu)?.[1];
    if (!name) continue;
    settings.subagents[name] = {
      ...(settings.subagents[name] ?? {}),
      ...(model ? { model } : {}),
      ...(thinking ? { thinking } : {}),
    };
  }
  writeFileSync(settingsPath, `${JSON.stringify(settings, null, 2)}\n`);
}

function killChild(child, signal = "SIGTERM") {
  if (!child.pid) return;
  try {
    if (process.platform === "win32") child.kill(signal);
    else process.kill(-child.pid, signal);
  } catch {
    // The process may already have settled.
  }
}

function runPi(options, cwd, prompt) {
  return new Promise((resolvePromise) => {
    const startedAt = Date.now();
    const child = spawn(
      "pi",
      ["--mode", "json", "--print", "--no-session", "--approve", "--model", options.model,
        ...(options.thinking ? ["--thinking", options.thinking] : []), prompt],
      {
        cwd,
        env: {
          ...process.env,
          PI_CODING_AGENT_DIR: options.piAgentDirectory,
          XDG_CONFIG_HOME: xdgConfigRoot,
        },
        detached: process.platform !== "win32",
        stdio: ["ignore", "pipe", "pipe"],
      },
    );
    activeChildren.add(child);
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    let settled = false;
    let escalation = null;
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    const timeout = setTimeout(() => {
      timedOut = true;
      killChild(child);
      escalation = setTimeout(() => killChild(child, "SIGKILL"), 5_000);
    }, options.timeoutMs);
    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      if (escalation) clearTimeout(escalation);
      activeChildren.delete(child);
      resolvePromise({
        ...result,
        stdout,
        stderr,
        timedOut,
        durationMs: Date.now() - startedAt,
      });
    };
    child.once("error", (error) => finish({ code: null, signal: null, spawnError: error.message }));
    child.once("close", (code, signal) => finish({ code, signal, spawnError: null }));
  });
}

function validateRun(scenario, fixture, beforeSnapshot, processResult, analysis) {
  const hardFailures = [];
  if (processResult.spawnError) hardFailures.push(`Pi spawn failed: ${processResult.spawnError}`);
  if (processResult.timedOut) hardFailures.push("Pi timed out");
  if (processResult.code !== 0) {
    hardFailures.push(`Pi exited with ${processResult.code ?? processResult.signal ?? "unknown status"}`);
  }
  if (analysis.malformed.length > 0) {
    hardFailures.push(`${analysis.malformed.length} malformed JSONL line(s)`);
  }
  if (analysis.missingActionCalls.length > 0) {
    hardFailures.push(`${analysis.missingActionCalls.length} subagent call(s) omitted action`);
  }
  if (analysis.schemaErrors.length > 0) {
    hardFailures.push(`${analysis.schemaErrors.length} subagent schema/validation error(s)`);
  }
  const runtimeErrors = analysis.subagentErrors.filter((error) => !analysis.schemaErrors.includes(error));
  const expectedErrors = scenario.hardExpectation?.expectedSubagentErrors ?? [];
  const errorEvaluation = evaluateExpectedSubagentErrors(runtimeErrors, expectedErrors);
  if (errorEvaluation.unexpected.length > 0) {
    hardFailures.push(`${errorEvaluation.unexpected.length} unexpected subagent execution error(s)`);
  }
  if (scenario.hardExpectation) {
    hardFailures.push(...evaluateExpectation(analysis, scenario.hardExpectation).reasons);
  }

  const repository = inspectFixture(fixture.directory);
  if (repository.head !== fixture.head) hardFailures.push("Pi created or changed a fixture commit");
  if (repository.diffCheck.status !== 0) {
    hardFailures.push(`git diff --check failed: ${repository.diffCheck.output}`);
  }
  let tests = null;
  if (scenario.workspace === "read-only") {
    if (snapshotFixture(fixture.directory) !== beforeSnapshot) {
      hardFailures.push("read-only scenario modified fixture files");
    }
  } else if (scenario.workspace === "implementation") {
    tests = testFixture(fixture.directory);
    if (tests.status !== 0) hardFailures.push("fixture tests failed after implementation");
    const allowed = new Set(["src/session.js", "test/session.test.js"]);
    const unexpected = repository.changedPaths.filter((path) => !allowed.has(path));
    if (unexpected.length > 0) hardFailures.push(`unexpected changed path(s): ${unexpected.join(", ")}`);
    for (const required of allowed) {
      if (!repository.changedPaths.includes(required)) hardFailures.push(`required path was not changed: ${required}`);
    }
  }
  return { hardFailures, repository, tests };
}

async function runOne(options, reportDirectory, runtimeDirectory, item) {
  const { scenario, repetition, order } = item;
  const runName = `${scenario.id}-${String(repetition).padStart(2, "0")}`;
  const fixtureDirectory = join(runtimeDirectory, runName);
  mkdirSync(fixtureDirectory, { recursive: true });
  const fixture = { directory: fixtureDirectory, ...createFixture(fixtureDirectory, scenario.fixture) };
  const beforeSnapshot = snapshotFixture(fixtureDirectory);
  console.log(`[${order + 1}] START ${runName}`);
  const processResult = await runPi(options, fixtureDirectory, scenario.prompt);
  writeFileSync(join(reportDirectory, `${runName}.jsonl`), processResult.stdout);
  writeFileSync(join(reportDirectory, `${runName}.stderr.log`), processResult.stderr);
  const analysis = analyzeJsonl(processResult.stdout);
  const validation = validateRun(scenario, fixture, beforeSnapshot, processResult, analysis);
  const behavioral = evaluateExpectation(analysis, scenario.expectation);
  const status = validation.hardFailures.length > 0 ? "FAIL" : behavioral.passed ? "PASS" : "WARN";
  console.log(
    `[${order + 1}] ${status} ${runName} agents=${analysis.subagentRoles.join("->") || "none"} actions=${analysis.subagentActions.join("->") || "none"}`,
  );
  return {
    scenarioId: scenario.id,
    repetition,
    order,
    prompt: scenario.prompt,
    durationMs: processResult.durationMs,
    exit: {
      code: processResult.code,
      signal: processResult.signal,
      timedOut: processResult.timedOut,
      spawnError: processResult.spawnError,
    },
    hardFailures: validation.hardFailures,
    behavioral,
    analysis: {
      ...analysis,
      finalText: analysis.finalText.slice(0, 2_000),
    },
    workspace: {
      changedPaths: validation.repository.changedPaths,
      tests: validation.tests,
      fixtureDirectory: options.keep ? fixtureDirectory : null,
    },
    artifacts: {
      jsonl: `${runName}.jsonl`,
      stderr: `${runName}.stderr.log`,
    },
  };
}

function configHash() {
  const hash = createHash("sha256");
  const agentDirectory = join(agentRoot, "agents");
  for (const name of readdirSync(agentDirectory).filter((name) => name.endsWith(".md")).sort()) {
    hash.update(name);
    hash.update("\0");
    hash.update(readFileSync(join(agentDirectory, name)));
  }
  for (const relativePath of [
    "subagent/index.ts",
    "subagent/eval/scenarios.mjs",
    "subagent/eval/analyze.mjs",
    "subagent/eval/fixture.mjs",
  ]) {
    hash.update(`${relativePath}\0`);
    hash.update(readFileSync(join(extensionsRoot, relativePath)));
  }
  return hash.digest("hex");
}

function baselineReport(path) {
  if (!path) return null;
  const reportPath = statSync(path).isDirectory() ? join(path, "report.json") : path;
  return JSON.parse(readFileSync(reportPath, "utf8"));
}

function percentage(value) {
  return `${(value * 100).toFixed(0)}%`;
}

function markdownReport(report) {
  const lines = [
    "# Pi subagent live evaluation",
    "",
    `- Timestamp: ${report.metadata.timestamp}`,
    `- Pi: ${report.metadata.piVersion}`,
    `- Model: ${report.metadata.model}`,
    `- Mode: ${report.metadata.mode} (${report.metadata.strict ? "strict" : "warning thresholds"})`,
    `- Config hash: \`${report.metadata.configHash}\``,
    "",
    "| Scenario | Runs | Behavior | Target | Hard failures | Agents/run | Cost | Status |",
    "| --- | ---: | ---: | ---: | ---: | --- | ---: | --- |",
  ];
  for (const scenario of report.summary.scenarios) {
    const agents = Object.entries(scenario.agents)
      .map(([agent, count]) => `${agent} ${count}/${scenario.runs}`)
      .join(", ") || "none";
    lines.push(
      `| ${scenario.id} | ${scenario.runs} | ${percentage(scenario.rate)} | ${percentage(scenario.targetRate)} | ${scenario.hardFailureCount} | ${agents} | $${scenario.cost.toFixed(4)} | ${scenario.status} |`,
    );
  }
  lines.push("", `Parent cost reported by Pi (child cost is not exposed): $${report.summary.totalCost.toFixed(4)}`);
  if (report.comparison) {
    lines.push(
      "",
      "## Baseline comparison",
      "",
      "| Scenario | Before | After | Delta | Hard failures before → after |",
      "| --- | ---: | ---: | ---: | --- |",
    );
    for (const comparison of report.comparison) {
      lines.push(
        `| ${comparison.id} | ${comparison.rateBefore === null ? "n/a" : percentage(comparison.rateBefore)} | ${percentage(comparison.rateAfter)} | ${comparison.rateDelta === null ? "n/a" : percentage(comparison.rateDelta)} | ${comparison.hardFailuresBefore ?? "n/a"} → ${comparison.hardFailuresAfter} |`,
      );
    }
  }
  const noteworthy = report.runs.filter((run) => run.hardFailures.length > 0 || !run.behavioral.passed);
  if (noteworthy.length > 0) {
    lines.push("", "## Failures and warnings", "");
    for (const run of noteworthy) {
      lines.push(`- **${run.scenarioId} #${run.repetition}**`);
      for (const failure of run.hardFailures) lines.push(`  - Hard: ${failure}`);
      for (const reason of run.behavioral.reasons) lines.push(`  - Behavior: ${reason}`);
    }
  }
  lines.push("");
  return lines.join("\n");
}

function prepareReportDirectory(path) {
  if (!path) return mkdtempSync(join(tmpdir(), "pi-subagent-eval-report-"));
  mkdirSync(path, { recursive: true });
  if (existsSync(join(path, "report.json"))) {
    throw new Error(`Report already exists: ${join(path, "report.json")}`);
  }
  return path;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(usage);
    return;
  }
  const selected = selectedScenarios(options);
  const plan = executionPlan(options, selected);
  console.log(`Mode: ${options.mode}; strict: ${options.strict}; model: ${options.model}${options.subagentModel ? `; subagent model: ${options.subagentModel}` : ""}${options.thinking ? `; thinking: ${options.thinking}` : ""}${options.subagentThinking ? `; subagent thinking: ${options.subagentThinking}` : ""}`);
  for (const scenario of selected) {
    const count = plan.filter((item) => item.scenario.id === scenario.id).length;
    console.log(`- ${scenario.id} x${count}: ${scenario.description}`);
  }
  console.log(`Total real Pi sessions: ${plan.length}`);
  if (options.dryRun) return;

  const reportDirectory = prepareReportDirectory(options.report);
  const runtimeDirectory = mkdtempSync(join(tmpdir(), "pi-subagent-eval-runtime-"));
  options.piAgentDirectory = createIsolatedAgentDirectory(runtimeDirectory);
  overrideSubagents(options.piAgentDirectory, options.subagentModel, options.subagentThinking);
  const cleanup = (signal = "SIGTERM") => {
    for (const child of activeChildren) killChild(child, signal);
    if (!options.keep) rmSync(runtimeDirectory, { recursive: true, force: true });
  };
  const interrupt = () => {
    cleanup("SIGKILL");
    process.exit(130);
  };
  process.once("SIGINT", interrupt);
  process.once("SIGTERM", interrupt);

  const runs = [];
  let cursor = 0;
  try {
    const piVersion = preflight(options);
    if (options.subagentModel && options.subagentModel !== options.model) {
      requireSuccess(
        sync("pi", ["auth", "check", "--model", options.subagentModel], extensionsRoot, {
          ...process.env,
          PI_CODING_AGENT_DIR: options.piAgentDirectory,
          XDG_CONFIG_HOME: xdgConfigRoot,
        }),
        `Pi authentication is not ready for ${options.subagentModel}`,
      );
    }
    const workers = Array.from({ length: Math.min(options.jobs, plan.length) }, async () => {
      while (cursor < plan.length) {
        const item = plan[cursor++];
        runs.push(await runOne(options, reportDirectory, runtimeDirectory, item));
      }
    });
    await Promise.all(workers);
    runs.sort((left, right) => left.order - right.order);
    const summaries = aggregateResults(runs, selected, options.strict);
    const baseline = baselineReport(options.baseline);
    const gitCommit = requireSuccess(sync("git", ["rev-parse", "HEAD"]), "Cannot read Git commit");
    const gitStatus = requireSuccess(sync("git", ["status", "--short"]), "Cannot read Git status");
    const report = {
      schemaVersion: 1,
      metadata: {
        timestamp: new Date().toISOString(),
        piVersion,
        model: options.model,
        subagentModel: options.subagentModel,
        subagentThinking: options.subagentThinking,
        mode: options.mode,
        strict: options.strict,
        jobs: options.jobs,
        timeoutMs: options.timeoutMs,
        gitCommit,
        gitDirty: gitStatus.length > 0,
        configHash: configHash(),
        runtimeDirectory: options.keep ? runtimeDirectory : null,
      },
      scenarios: selected.map(({ prompt, ...scenario }) => scenario),
      runs,
      summary: {
        scenarios: summaries,
        totalRuns: runs.length,
        totalCost: summaries.reduce((sum, scenario) => sum + scenario.cost, 0),
        hardFailureCount: summaries.reduce((sum, scenario) => sum + scenario.hardFailureCount, 0),
        failedScenarioCount: summaries.filter((scenario) => scenario.status === "fail").length,
        warningScenarioCount: summaries.filter((scenario) => scenario.status === "warn").length,
      },
      comparison: baseline ? compareSummaries(summaries, baseline) : null,
    };
    writeFileSync(join(reportDirectory, "report.json"), `${JSON.stringify(report, null, 2)}\n`);
    writeFileSync(join(reportDirectory, "summary.md"), markdownReport(report));
    console.log(`\n${markdownReport(report)}`);
    console.log(`Artifacts: ${reportDirectory}`);
    if (report.summary.failedScenarioCount > 0) process.exitCode = 1;
  } finally {
    process.removeListener("SIGINT", interrupt);
    process.removeListener("SIGTERM", interrupt);
    cleanup();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
