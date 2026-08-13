function asObject(value) {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value;
  }
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
    } catch {
      return {};
    }
  }
  return {};
}

function textContent(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .filter((part) => part && typeof part === "object" && part.type === "text")
    .map((part) => typeof part.text === "string" ? part.text : "")
    .join("\n");
}

function errorText(event) {
  const result = event.result;
  if (typeof result === "string") return result;
  if (result && typeof result === "object") {
    if (Array.isArray(result.content)) return textContent(result.content);
    if (typeof result.error === "string") return result.error;
    if (typeof result.message === "string") return result.message;
  }
  if (typeof event.error === "string") return event.error;
  if (event.error && typeof event.error.message === "string") return event.error.message;
  return "";
}

function number(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

const WORK_ORDER_FIELD_PATTERNS = {
  outcome: /(?:\bgoal\b|\boutcome\b|\bobjective\b|\bimplement\b|\bfix\b|\bmap\b|\bresearch\b|\breview\b|\bdecide\b|目标|结果)/iu,
  scope: /(?:\bscope\b|\bfiles?\b|\bpaths?\b|src\/|test\/|plan\.md|范围|文件)/iu,
  startingEvidence: /(?:starting (?:evidence|context)|\bevidence\b|\bcontext\b|plan\.md|\bknown\b|\binspect\b|上下文|证据)/iu,
  decisions: /(?:known decisions?|user decisions?|must (?:keep|preserve)|keep .+ stable|决策|保持)/iu,
  constraints: /(?:\bconstraints?\b|non-goals?|do not|must not|preserve unrelated|read-only|约束|非目标|不要)/iu,
  acceptance: /(?:acceptance criteria|done when|complete when|must (?:pass|include|change|find|report)|验收)/iu,
  validation: /(?:\bvalidation\b|\bvalidate\b|\bverify\b|run .{0,40}\btests?\b|npm test|node --test|验证|测试)/iu,
  handoff: /(?:\bhandoff\b|\breturn\b|\breport\b|\bdeliver\b|交付|返回|报告)/iu,
};

function classifyWorkOrder(task) {
  return Object.fromEntries(
    Object.entries(WORK_ORDER_FIELD_PATTERNS).map(([field, pattern]) => [field, pattern.test(task)]),
  );
}

export function parseJsonl(source) {
  const events = [];
  const malformed = [];
  for (const [index, line] of source.split(/\r?\n/u).entries()) {
    if (!line.trim()) continue;
    try {
      const event = JSON.parse(line);
      if (!event || typeof event !== "object" || Array.isArray(event)) {
        malformed.push({ line: index + 1, text: line });
      } else {
        events.push(event);
      }
    } catch {
      malformed.push({ line: index + 1, text: line });
    }
  }
  return { events, malformed };
}

export function analyzeJsonl(source) {
  const { events, malformed } = parseJsonl(source);
  const tools = events
    .map((event, index) => ({ event, index }))
    .filter(({ event }) => event.type === "tool_execution_start")
    .map(({ event, index }) => ({
      name: event.toolName ?? event.tool?.name ?? event.name ?? "",
      args: asObject(event.args ?? event.arguments ?? event.input),
      id: event.toolCallId ?? event.id ?? null,
      eventIndex: index,
    }));
  const subagentCalls = tools.filter((tool) => tool.name === "subagent");
  const subagentEnds = events
    .map((event, index) => ({
      event,
      index,
      id: event.toolCallId ?? event.id ?? null,
    }))
    .filter(({ event }) => event.type === "tool_execution_end"
      && (event.toolName ?? event.tool?.name ?? event.name ?? "") === "subagent");
  const initialSubagentCalls = subagentCalls.filter((call) => ["run", "start"].includes(call.args.action));
  const unmatchedEnds = new Set(subagentEnds);
  const subagentSettlements = initialSubagentCalls.map((call) => {
    const end = call.id === null
      ? [...unmatchedEnds].find((candidate) => candidate.index > call.eventIndex)
      : [...unmatchedEnds].find((candidate) => candidate.id === call.id);
    if (end) unmatchedEnds.delete(end);
    return {
      agent: typeof call.args.agent === "string" ? call.args.agent : null,
      callIndex: call.eventIndex,
      endIndex: end?.index ?? null,
    };
  });
  const subagentWorkOrders = initialSubagentCalls.map((call) => {
    const task = typeof call.args.task === "string" ? call.args.task : "";
    return {
      agent: typeof call.args.agent === "string" ? call.args.agent : null,
      task,
      fields: classifyWorkOrder(task),
    };
  });
  const subagentRoles = subagentCalls
    .filter((call) => ["run", "start"].includes(call.args.action) && typeof call.args.agent === "string")
    .map((call) => call.args.agent);
  const subagentActions = subagentCalls
    .map((call) => call.args.action)
    .filter((action) => typeof action === "string");
  const parentToolCounts = {};
  for (const tool of tools) {
    parentToolCounts[tool.name] = (parentToolCounts[tool.name] ?? 0) + 1;
  }

  const subagentHandoffFields = subagentEnds.map(({ event }) => {
    const text = errorText(event);
    return {
      evidence: /(?:^|\n)\s*(?:#+\s*)?evidence(?:\s|:)/iu.test(text),
      validation: /(?:^|\n)\s*(?:#+\s*)?validation(?:\s|:)/iu.test(text),
      blockers: /(?:^|\n)\s*(?:#+\s*)?blockers?(?:\s|:)/iu.test(text),
      risks: /(?:^|\n)\s*(?:#+\s*)?(?:residual\s+)?risks?(?:\s|:)/iu.test(text),
    };
  });

  const toolErrors = events
    .filter((event) => event.type === "tool_execution_end")
    .filter((event) => event.isError === true || event.result?.isError === true || event.error)
    .map((event) => ({
      name: event.toolName ?? event.tool?.name ?? event.name ?? "",
      text: errorText(event),
    }));
  const schemaErrors = toolErrors.filter((error) =>
    error.name === "subagent"
      && /(?:argument|parameter|schema|validation|required|must include|action)/iu.test(error.text)
  );
  const subagentErrors = toolErrors.filter((error) => error.name === "subagent");

  const assistantMessages = events
    .filter((event) => event.type === "message_end" && event.message?.role === "assistant")
    .map((event) => event.message);
  const finalText = assistantMessages.length > 0
    ? textContent(assistantMessages.at(-1).content)
    : "";
  const usage = assistantMessages.reduce((total, message) => {
    const current = message.usage ?? {};
    total.inputTokens += number(current.input ?? current.inputTokens);
    total.outputTokens += number(current.output ?? current.outputTokens);
    total.cacheReadTokens += number(current.cacheRead ?? current.cacheReadTokens);
    total.cacheWriteTokens += number(current.cacheWrite ?? current.cacheWriteTokens);
    total.totalTokens += number(current.totalTokens);
    total.cost += number(current.cost?.total ?? current.cost);
    return total;
  }, {
    inputTokens: 0,
    outputTokens: 0,
    cacheReadTokens: 0,
    cacheWriteTokens: 0,
    totalTokens: 0,
    cost: 0,
  });

  return {
    eventCount: events.length,
    malformed,
    tools,
    parentToolCounts,
    subagentCalls,
    subagentRoles,
    subagentActions,
    missingActionCalls: subagentCalls.filter((call) => typeof call.args.action !== "string"),
    toolErrors,
    subagentErrors,
    schemaErrors,
    finalText,
    usage,
    subagentEnds,
    subagentSettlements,
    subagentWorkOrders,
    subagentHandoffFields,
    parallelSubagentStarts: subagentCalls
      .filter((call) => ["run", "start"].includes(call.args.action))
      .filter((call) => {
        const firstSubagentEnd = events.findIndex((event) =>
          event.type === "tool_execution_end"
          && (event.toolName ?? event.tool?.name ?? event.name ?? "") === "subagent",
        );
        return firstSubagentEnd >= 0 && call.eventIndex < firstSubagentEnd;
      })
      .map((call) => call.args.agent)
      .filter((agent) => typeof agent === "string"),
  };
}

function containsOrdered(actual, expected, matches = (left, right) => left === right) {
  if (expected.length === 0) return true;
  let cursor = 0;
  for (const value of actual) {
    if (matches(value, expected[cursor])) cursor += 1;
    if (cursor === expected.length) return true;
  }
  return false;
}

export function evaluateExpectation(analysis, expectation = {}) {
  const reasons = [];
  for (const agent of expectation.requiredAgents ?? []) {
    if (!analysis.subagentRoles.includes(agent)) reasons.push(`missing ${agent} subagent`);
  }
  for (const agent of expectation.forbiddenAgents ?? []) {
    if (analysis.subagentRoles.includes(agent)) reasons.push(`unexpected ${agent} subagent`);
  }
  if (
    expectation.maxSubagentCalls !== undefined
    && analysis.subagentCalls.length > expectation.maxSubagentCalls
  ) {
    reasons.push(
      `subagent calls ${analysis.subagentCalls.length} > ${expectation.maxSubagentCalls}`,
    );
  }
  if (
    expectation.agentOrder
    && !containsOrdered(analysis.subagentRoles, expectation.agentOrder)
  ) {
    reasons.push(
      `agent order ${analysis.subagentRoles.join(" -> ") || "(none)"} does not contain ${expectation.agentOrder.join(" -> ")}`,
    );
  }
  if (expectation.agentsBefore) {
    const boundary = analysis.subagentSettlements?.find(
      (candidate) => candidate.agent === expectation.agentsBefore.before,
    );
    for (const agent of expectation.agentsBefore.agents) {
      const prerequisite = analysis.subagentSettlements?.find((candidate) => candidate.agent === agent);
      if (
        !boundary
        || !prerequisite
        || prerequisite.callIndex >= boundary.callIndex
        || prerequisite.endIndex === null
        || prerequisite.endIndex >= boundary.callIndex
      ) {
        reasons.push(`${agent} did not settle before ${expectation.agentsBefore.before} started`);
      }
    }
  }
  if (expectation.actionSequence) {
    const calls = analysis.subagentCalls.map((call) => call.args);
    const matched = containsOrdered(calls, expectation.actionSequence, (actual, expected) =>
      Object.entries(expected).every(([key, value]) => actual[key] === value)
    );
    if (!matched) {
      reasons.push(
        `action sequence ${analysis.subagentActions.join(" -> ") || "(none)"} does not match expectation`,
      );
    }
  }
  for (const [agent, fields] of Object.entries(expectation.workOrderFields ?? {})) {
    const workOrder = analysis.subagentWorkOrders?.find((candidate) => candidate.agent === agent);
    for (const field of fields) {
      if (!workOrder?.fields[field]) reasons.push(`${agent} work order missing ${field}`);
    }
  }
  for (const required of expectation.parentToolCallsAfter ?? []) {
    const settlement = analysis.subagentSettlements
      ?.filter((candidate) => candidate.agent === required.agent && candidate.endIndex !== null)
      .at(-1);
    const pattern = new RegExp(required.argsMatch, "isu");
    const matched = settlement && analysis.tools.some((tool) =>
      tool.eventIndex > settlement.endIndex
      && tool.name === required.tool
      && pattern.test(JSON.stringify(tool.args)),
    );
    if (!matched) {
      reasons.push(
        `parent did not call ${required.tool} matching /${required.argsMatch}/ after ${required.agent} settled`,
      );
    }
  }
  for (const [tool, limits] of Object.entries(expectation.parentToolCounts ?? {})) {
    const count = analysis.parentToolCounts[tool] ?? 0;
    if (limits.min !== undefined && count < limits.min) {
      reasons.push(`${tool} count ${count} < ${limits.min}`);
    }
    if (limits.max !== undefined && count > limits.max) {
      reasons.push(`${tool} count ${count} > ${limits.max}`);
    }
  }
  if (expectation.finalAny?.length) {
    const matched = expectation.finalAny.some((source) => new RegExp(source, "isu").test(analysis.finalText));
    if (!matched) reasons.push("final answer does not contain the expected outcome evidence");
  }
  if (expectation.parallelAgents) {
    const actual = analysis.parallelSubagentStarts ?? [];
    for (const agent of expectation.parallelAgents) {
      if (!actual.includes(agent)) reasons.push(`${agent} was not started before the first subagent settled`);
    }
  }
  if (expectation.handoffFields) {
    for (const field of expectation.handoffFields) {
      if (!analysis.subagentHandoffFields?.every((handoff) => handoff[field])) {
        reasons.push(`subagent handoff missing ${field}`);
      }
    }
  }
  return { passed: reasons.length === 0, reasons };
}

export function aggregateResults(runs, scenarios, strict) {
  return scenarios.map((scenario) => {
    const selected = runs.filter((run) => run.scenarioId === scenario.id);
    const behavioralPasses = selected.filter((run) => run.behavioral.passed).length;
    const hardFailureCount = selected.reduce((sum, run) => sum + run.hardFailures.length, 0);
    const rate = selected.length === 0 ? 0 : behavioralPasses / selected.length;
    const behavioralFailure = rate < scenario.targetRate;
    return {
      id: scenario.id,
      runs: selected.length,
      behavioralPasses,
      rate,
      targetRate: scenario.targetRate,
      hardFailureCount,
      cost: selected.reduce((sum, run) => sum + run.analysis.usage.cost, 0),
      durationMs: selected.reduce((sum, run) => sum + run.durationMs, 0),
      status: hardFailureCount > 0 || (strict && behavioralFailure)
        ? "fail"
        : behavioralFailure ? "warn" : "pass",
      agents: Object.fromEntries(
        [...new Set(selected.flatMap((run) => run.analysis.subagentRoles))]
          .sort()
          .map((agent) => [
            agent,
            selected.filter((run) => run.analysis.subagentRoles.includes(agent)).length,
          ]),
      ),
    };
  });
}

export function compareSummaries(current, baseline) {
  const previous = new Map((baseline.summary?.scenarios ?? []).map((scenario) => [scenario.id, scenario]));
  return current.map((scenario) => {
    const before = previous.get(scenario.id);
    return {
      id: scenario.id,
      rateBefore: before?.rate ?? null,
      rateAfter: scenario.rate,
      rateDelta: before ? scenario.rate - before.rate : null,
      hardFailuresBefore: before?.hardFailureCount ?? null,
      hardFailuresAfter: scenario.hardFailureCount,
      costBefore: before?.cost ?? null,
      costAfter: scenario.cost,
    };
  });
}
