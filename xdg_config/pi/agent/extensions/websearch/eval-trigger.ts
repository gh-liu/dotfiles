/**
 * Trigger-rate evaluation for the web_search tool ("唤醒概率").
 *
 * Measures how reliably the model invokes `web_search` when it should
 * (fresh-info prompts) and how often it falsely invokes it when it should not
 * (stable-knowledge prompts), comparing tool-description variants head-to-head.
 *
 * Isolation guarantees (so only name/description/promptSnippet drive the result):
 * - Only the websearch extension is loaded (no other extensions/skills/prompts/themes).
 * - No context files (AGENTS.md) and no built-in tools (web_search is the ONLY tool).
 * - Neutral system prompt, fresh in-memory session per run.
 * - Real Exa API is called when triggered (EXA_API_KEY must be set); cost ~$0.007/search.
 *
 * Usage:
 *   cd xdg_config/pi/agent/extensions && bun websearch/eval-trigger.ts
 *   bun websearch/eval-trigger.ts --only current        # run one variant
 *   bun websearch/eval-trigger.ts --repeats 2           # repeat each case
 *   bun websearch/eval-trigger.ts --smoke               # 1 case per variant, harness sanity check
 *
 * Results are written to websearch/eval-trigger-results.json next to this file.
 *
 * Latest run (2026-08-22, model openrouter-free/stealth/ox-alpha, thinking=low):
 * current description already achieves 12/12 hits and 0/5 false positives —
 * no description improvement warranted; "improved" variant showed no gain
 * (ceiling effect). Re-run if the tool name/description changes or a new
 * default model ships.
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
	createAgentSession,
	DefaultResourceLoader,
	ModelRuntime,
	SessionManager,
	SettingsManager,
	type Model,
	type ModelRuntime as ModelRuntimeType,
} from "@earendil-works/pi-coding-agent";
import { registerWebSearchExtension } from "./index.ts";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const RESULTS_PATH = new URL("./eval-trigger-results.json", import.meta.url).pathname;
const THINKING_LEVEL = "low"; // conservative lower bound; rerun at higher levels if borderline
const RUN_TIMEOUT_MS = 180_000;
const CONCURRENCY = 3;
const RETRIES_PER_RUN = 1;

const NEUTRAL_SYSTEM_PROMPT =
	"You are a helpful assistant. Use the available tools when they help you answer accurately. Answer briefly in the user's language.";

type Variant = {
	name: string;
	description?: string;
	promptSnippet?: string;
};

const VARIANTS: Variant[] = [
	{ name: "current" },
	{
		name: "improved",
		description:
			"Search the live web with Exa for fresh or fast-changing information: recent news and events, latest software releases and versions, current prices, schedules, scores, weather, and up-to-date docs. Use it whenever the answer depends on what is true now or very recently, or when the user asks to search or look something up online; skip it for stable concepts, math, translations, or questions about the local codebase. Returns URLs and token-efficient highlights by default; use full text only for deeper source analysis.",
		promptSnippet:
			"Search the live web for freshness-sensitive info: news, releases, versions, prices, docs",
	},
];

type Case = { id: string; expect: boolean; prompt: string };

const CASES: Case[] = [
	// --- positive: answer depends on fresh/current info -> should call web_search
	{ id: "explicit-search-zh", expect: true, prompt: "帮我搜一下 Exa API 现在的定价。" },
	{ id: "news-last-week-en", expect: true, prompt: "What did Anthropic announce in the last week?" },
	{ id: "version-lts-zh", expect: true, prompt: "Node.js 目前最新的 LTS 版本是多少？" },
	{ id: "release-stable-en", expect: true, prompt: "Has React 19 been released as stable? When?" },
	{ id: "docs-latest-zh", expect: true, prompt: "查一下 TypeScript 最新版本有哪些新特性。" },
	{ id: "stock-live-en", expect: true, prompt: "What is Tesla's stock price right now?" },
	{ id: "crypto-live-zh", expect: true, prompt: "现在比特币价格大概是多少美元？" },
	{ id: "ai-news-zh", expect: true, prompt: "最近一周 AI 行业有什么大新闻？" },
	{ id: "weather-zh", expect: true, prompt: "上海这个周末的天气怎么样？" },
	{ id: "sports-score-en", expect: true, prompt: "What was the score of the most recent Lakers game?" },
	{
		id: "lib-version-en",
		expect: true,
		prompt: "What is the latest stable version of Bun and its headline features?",
	},
	{ id: "event-date-zh", expect: true, prompt: "今年苹果秋季发布会定在什么时候？" },
	// --- negative: stable knowledge -> should NOT call web_search
	{ id: "concept-zh", expect: false, prompt: "用一句话解释什么是快速排序。" },
	{ id: "math-zh", expect: false, prompt: "100 以内一共有多少个质数？" },
	{ id: "translate-zh", expect: false, prompt: "把 'hello world' 翻译成法语，只给结果。" },
	{
		id: "code-local-en",
		expect: false,
		prompt: "Write a Python function that checks whether a string is a palindrome.",
	},
	{ id: "idiom-zh", expect: false, prompt: "'锲而不舍' 是什么意思？" },
];

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

type RunResult = {
	variant: string;
	caseId: string;
	expect: boolean;
	triggered: boolean;
	searchCalls: number;
	toolsUsed: string[];
	error?: string;
	finalText?: string;
	durationMs: number;
};

function parseArgs(argv: string[]) {
	const args: Record<string, string | number | boolean> = {};
	for (let i = 0; i < argv.length; i++) {
		if (argv[i] === "--only") args.only = argv[++i];
		if (argv[i] === "--repeats") args.repeats = Number(argv[++i]);
		if (argv[i] === "--smoke") args.smoke = true;
	}
	return args;
}

function withTimeout<T>(p: Promise<T>, ms: number, onTimeout: () => void): Promise<T> {
	return new Promise<T>((resolve, reject) => {
		const timer = setTimeout(() => {
			onTimeout();
			reject(new Error(`timeout after ${ms}ms`));
		}, ms);
		p.then(
			(v) => {
				clearTimeout(timer);
				resolve(v);
			},
			(e) => {
				clearTimeout(timer);
				reject(e instanceof Error ? e : new Error(String(e)));
			},
		);
	});
}

async function buildSession(variant: Variant, modelRuntime: ModelRuntimeType) {
	const workDir = fs.mkdtempSync(path.join(os.tmpdir(), "ws-eval-cwd-"));
	const agentDir = fs.mkdtempSync(path.join(os.tmpdir(), "ws-eval-agent-"));
	const loader = new DefaultResourceLoader({
		cwd: workDir,
		agentDir,
		noExtensions: true,
		noSkills: true,
		noPromptTemplates: true,
		noThemes: true,
		noContextFiles: true,
		// Register the REAL extension factory with the variant's description/promptSnippet
		// so A/B differs only in the strings exposed to the model.
		extensionFactories: [
			{
				name: `websearch-${variant.name}`,
				factory: (pi) => registerWebSearchExtension(pi, {
					description: variant.description,
					promptSnippet: variant.promptSnippet,
				}),
			},
		],
		systemPromptOverride: () => NEUTRAL_SYSTEM_PROMPT,
	});
	await loader.reload();

	const settingsManager = SettingsManager.inMemory({
		compaction: { enabled: false },
	});

	const { session } = await createAgentSession({
		cwd: workDir,
		agentDir,
		modelRuntime,
		thinkingLevel: THINKING_LEVEL,
		resourceLoader: loader,
		noTools: "builtin",
		sessionManager: SessionManager.inMemory(workDir),
		settingsManager,
	});
	return { session, cleanup: () => fs.rmSync(workDir, { recursive: true, force: true }) };
}

async function runOnce(
	variant: Variant,
	testCase: Case,
	model: Model<any>,
	modelRuntime: ModelRuntimeType,
): Promise<RunResult> {
	const started = Date.now();
	const base: Omit<RunResult, "triggered" | "searchCalls" | "toolsUsed" | "durationMs"> = {
		variant: variant.name,
		caseId: testCase.id,
		expect: testCase.expect,
	};

	const { session, cleanup } = await buildSession(variant, modelRuntime);
	let searchCalls = 0;
	const toolsUsed: string[] = [];
	try {
		session.subscribe((event) => {
			if (event.type === "tool_execution_start") {
				toolsUsed.push(event.toolName);
				if (event.toolName === "web_search") searchCalls++;
			}
		});
		await withTimeout(
			session.prompt(testCase.prompt),
			RUN_TIMEOUT_MS,
			() => void session.abort(),
		);
		const errorMessage = session.agent.state.errorMessage ?? undefined;
		const lastAssistant = [...session.agent.state.messages]
			.reverse()
			.find((m) => m.role === "assistant");
		const finalText = Array.isArray(lastAssistant?.content)
			? lastAssistant.content
					.filter((c): c is { type: "text"; text: string } => c.type === "text")
					.map((c) => c.text)
					.join("\n")
					.slice(0, 300)
			: undefined;
		return {
			...base,
			triggered: searchCalls > 0,
			searchCalls,
			toolsUsed,
			error: errorMessage,
			finalText,
			durationMs: Date.now() - started,
		};
	} catch (error) {
		return {
			...base,
			triggered: searchCalls > 0,
			searchCalls,
			toolsUsed,
			error: error instanceof Error ? error.message : String(error),
			durationMs: Date.now() - started,
		};
	} finally {
		session.dispose();
		cleanup();
	}
}

async function runWithRetry(
	variant: Variant,
	testCase: Case,
	model: Model<any>,
	modelRuntime: ModelRuntimeType,
): Promise<RunResult> {
	let last: RunResult | undefined;
	for (let attempt = 0; attempt <= RETRIES_PER_RUN; attempt++) {
		last = await runOnce(variant, testCase, model, modelRuntime);
		// Retry only on transport/model errors, not on "model chose not to search".
		if (!last.error) return last;
		console.warn(`  [retry ${attempt + 1}] ${variant.name}/${testCase.id}: ${last.error}`);
	}
	return last!;
}

async function pool<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
	const results: R[] = new Array(items.length);
	let next = 0;
	async function worker() {
		while (next < items.length) {
			const index = next++;
			results[index] = await fn(items[index]);
		}
	}
	await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
	return results;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
	const args = parseArgs(process.argv.slice(2));
	const repeats = typeof args.repeats === "number" ? args.repeats : 1;
	const variants = VARIANTS.filter((v) => !args.only || v.name === args.only);
	if (variants.length === 0) throw new Error(`unknown --only variant: ${args.only}`);
	const cases = args.smoke ? CASES.slice(0, 1) : CASES;

	const modelRuntime = await ModelRuntime.create();
	const model =
		modelRuntime.getModel("openrouter-free", "stealth/ox-alpha") ??
		(await modelRuntime.getAvailable())[0];
	if (!model) throw new Error("No available model configured");
	console.log(`Model: ${model.provider}/${model.id}  thinking=${THINKING_LEVEL}`);
	console.log(`Cases: ${cases.length}  Variants: ${variants.map((v) => v.name).join(", ")}  Repeats: ${repeats}${args.smoke ? "  (smoke)" : ""}\n`);

	const jobs: Array<{ variant: Variant; testCase: Case }> = [];
	for (const variant of variants)
		for (const testCase of cases)
			for (let r = 0; r < repeats; r++) jobs.push({ variant, testCase });

	const runs: RunResult[] = [];
	let done = 0;
	await pool(jobs, CONCURRENCY, async (job) => {
		const result = await runWithRetry(job.variant, job.testCase, model, modelRuntime);
		runs.push(result);
		done++;
		const flag = result.error ? "ERR" : result.triggered === job.testCase.expect ? "ok " : "MISS";
		console.log(
			`[${String(done).padStart(3)}/${jobs.length}] ${flag} ${result.variant.padEnd(8)} ${result.caseId.padEnd(20)} calls=${result.searchCalls} ${(result.durationMs / 1000).toFixed(1)}s${result.error ? ` err=${result.error}` : ""}`,
		);
	});

	// Summary
	const summary: Record<string, object> = {};
	for (const variant of variants) {
		const rs = runs.filter((r) => r.variant === variant.name && !r.error);
		const pos = rs.filter((r) => r.expect);
		const neg = rs.filter((r) => !r.expect);
		summary[variant.name] = {
			validRuns: rs.length,
			hitRate: `${pos.filter((r) => r.triggered).length}/${pos.length}`,
			falsePositives: `${neg.filter((r) => r.triggered).length}/${neg.length}`,
		};
	}

	const payload = {
		meta: {
			date: new Date().toISOString(),
			model: `${model.provider}/${model.id}`,
			thinkingLevel: THINKING_LEVEL,
			systemPrompt: NEUTRAL_SYSTEM_PROMPT,
			repeats,
			cases: CASES,
		},
		summary,
		runs,
	};
	fs.writeFileSync(RESULTS_PATH, JSON.stringify(payload, null, 2));

	console.log("\n=== Summary (valid runs only) ===");
	for (const [name, s] of Object.entries(summary)) {
		const stats = s as { hitRate: string; falsePositives: string };
		console.log(`${name.padEnd(8)}  hit=${stats.hitRate}  falsePositive=${stats.falsePositives}`);
	}
	console.log(`\nResults written to ${RESULTS_PATH}`);
}

main().catch((error) => {
	console.error(error);
	process.exit(1);
});
