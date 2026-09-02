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

function resultText(value) {
  if (typeof value === "string") {
    try {
      const parsed = JSON.parse(value);
      if (parsed && typeof parsed === "object") return resultText(parsed);
    } catch {
      // Plain text result.
    }
    return value;
  }
  if (value && typeof value === "object") {
    const parts = [];
    if (Array.isArray(value.content)) parts.push(resultText(textContent(value.content)));
    for (const key of ["summary", "message", "error"]) {
      if (typeof value[key] === "string") parts.push(resultText(value[key]));
    }
    return parts.filter(Boolean).join("\n");
  }
  return "";
}

function errorText(event) {
  const text = resultText(event.result);
  if (text) return text;
  if (typeof event.error === "string") return event.error;
  if (event.error && typeof event.error.message === "string") return event.error.message;
  return "";
}

function number(value) {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
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
  const initialSubagentCalls = subagentCalls.filter((call) => call.args.action === "run");
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
  const subagentRoles = subagentCalls
    .filter((call) => call.args.action === "run" && typeof call.args.agent === "string")
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
      evidence: /(?:^|\n)\s*(?:[-*]\s*)?(?:#+\s*)?evidence(?:\s|:)/iu.test(text),
      validation: /(?:^|\n)\s*(?:[-*]\s*)?(?:#+\s*)?validation(?:\s|:)/iu.test(text),
      blockers: /(?:^|\n)\s*(?:[-*]\s*)?(?:#+\s*)?blockers?(?:\s|:)/iu.test(text),
      risks: /(?:^|\n)\s*(?:[-*]\s*)?(?:#+\s*)?(?:residual\s+)?risks?(?:\s|:)/iu.test(text),
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
    subagentHandoffFields,
    parallelSubagentStarts: subagentCalls
      .filter((call) => call.args.action === "run")
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

export function evaluateExpectedSubagentErrors(errors, expectations = []) {
  const remaining = [...errors];
  const reasons = [];
  for (const expectation of expectations) {
    const pattern = new RegExp(expectation.pattern, "isu");
    const matches = remaining
      .map((error, index) => ({ error, index }))
      .filter(({ error }) => pattern.test(error.text));
    if (matches.length !== expectation.count) {
      reasons.push(
        `subagent errors matching /${expectation.pattern}/: ${matches.length} != ${expectation.count}`,
      );
    }
    for (const { index } of matches.slice(0, expectation.count).reverse()) remaining.splice(index, 1);
  }
  return { reasons, unexpected: remaining };
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
  reasons.push(...evaluateExpectedSubagentErrors(
    analysis.subagentErrors.filter((error) => !analysis.schemaErrors.includes(error)),
    expectation.expectedSubagentErrors,
  ).reasons);
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
