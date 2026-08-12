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
    .filter((event) => event.type === "tool_execution_start")
    .map((event) => ({
      name: event.toolName ?? event.tool?.name ?? event.name ?? "",
      args: asObject(event.args ?? event.arguments ?? event.input),
      id: event.toolCallId ?? event.id ?? null,
    }));
  const subagentCalls = tools.filter((tool) => tool.name === "subagent");
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
    const boundary = analysis.subagentRoles.indexOf(expectation.agentsBefore.before);
    for (const agent of expectation.agentsBefore.agents) {
      const index = analysis.subagentRoles.indexOf(agent);
      if (boundary < 0 || index < 0 || index >= boundary) {
        reasons.push(`${agent} did not precede ${expectation.agentsBefore.before}`);
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
