# Subagent 自进化日志

> 规则：每次自进化必须小步、可验证、可回滚。记录目标、证据、改动、验证、风险。

## 2026-08-24 Iteration 1 — live-ui idle 行可观测性

- **目标**：让 background idle 行不再只是“holds slot”，而是携带 outcome + elapsed，便于父模型与人一眼判断是否需要 `close #N` 还是 `follow-up`。
- **证据**：
  - `live-ui.ts:108` 原 idle 行仅 `holds slot`，`settle(runId, _outcome, _elapsedMs)` 显式忽略参数（注释 `Outcome and elapsed are accepted for future polish`）
  - `live-ui.test.ts:198` 仅断言 idle 包含 `holds slot`，未校验 outcome
  - `runtime.ts:132` 已传递 `elapsedMs` 给 `notifySettled`，但 live-ui 丢弃
- **改动**：
  - `live-ui.ts` `RuntimeDisplay` 新增 `outcome`、`elapsedMs`
  - `renderLines` idle 分支拼接 `· {elapsed} ✓/✗/■ · holds slot`（保持 `truncateToWidth` 与 `dim`）
  - `settle` 存储 outcome/elapsed，仅 background 生效，foreground 仍立即 detach（不变）
- **验证**：
  - `npm test --prefix extensions` → 13 files 205 tests passed（typecheck:subagent + context）
  - `tmux capture-pane -t %0` 尝试 `/reload` 时收到 `Wait for the current response to finish before reloading.` — 符合预期（pi 在工具执行期间屏蔽 reload），下一 turn 即可 reload 生效
  - 保留原有断言 `contains holds slot`，新增行为不破坏契约
- **风险与回滚**：纯展示层，失败仅影响 widget 一行；回滚 = revert 本次 3 处 edits
- **下一步**：
  - 下一 turn 执行 `/reload` 并 `tmux capture-pane` 截图
  - 触发一个 `start` background 任务，观察 idle 行变为 `○ #1 scout ⟨bg⟩ · idle · 4s ✓ · holds slot`
  - 可选：在 `live-ui.test.ts` 追加断言 `idle line contains elapsed + marker`

## 待进化池（按 SPEC §16 与可验证性排序）

1. **render.ts** completion card 聚合去噪：当前 batched 通知首行标题截断 160ch，考虑将 `elapsedMs` 同步到 title 旁，复用 live-ui 的 `formatDuration`
2. **runtime.ts** 容量反馈：`maxConcurrentRuns=3` 失败时仅文字错误，可让 `response` 附带 `availableSlots` 便于父模型退避重试
3. **sdk-executor.ts** 可观测埋点：`onProgress` 已有 `X done · working…`，可追加 token 用量心跳（需成本评估）

## 2026-08-24 Iteration 2 — live-ui idle outcome marker 着色

- **目标**：让 background idle 行的 completed / failed / interrupted outcome marker 跟随主题着色（success / error / warning），同时保留 elapsed 与 holds slot 文案。
- **证据**：Iteration 1 已在 idle 行拼接 `· {elapsed} ✓/✗/■ · holds slot`，但 marker 仍包含在整体 dim 字符串中，无法一眼区分 outcome。
- **改动**：`live-ui.ts` idle 分支保持 `truncateToWidth` 与 dim 文案，仅将 marker 片段改为 `theme.fg("success"|"error"|"warning", marker)`；`live-ui.test.ts` 增加 fake timers 用例覆盖 3 个 outcome 的 marker 颜色与无 elapsed 时的回落显示。
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions`；`tsc -p xdg_config/pi/agent/extensions/subagent/tsconfig.json`。
- **风险与回滚**：纯展示层变更，依赖主题色名沿用既有 render.ts；回滚 = revert Iteration 2 对 live-ui.ts / live-ui.test.ts / EVOLVE_LOG.md 的追加改动。

## 2026-08-24 Iteration 3 — runtime live settle elapsed 透传

- **现象**：真机 background idle capture 显示 `○ #1 scout ⟨bg⟩ · idle ✓ · holds slot`，缺少预期的 `· Xs`；而测试中直接调用 `live.settle("r1", "completed", 4200)` 可渲染 `· 4s`。
- **根因**：`beginOperation` 的 `started.result.then` 成功与失败分支只调用 `deps.live.settle(runId, outcome)`，未传递 live-ui 已支持的第三个 `elapsedMs` 参数；此时 `finishedAt` 尚未在 `finally` 中赋值，不能依赖最终 settle 通知的计算结果。
- **改动**：在成功与失败分支中用 `Date.now() - (operation.startedAt ?? Date.now())` 计算当前 operation elapsed，并传给 `deps.live.settle`；不改动 live-ui 的 truncate / 着色逻辑，也不改动通知卡片逻辑。
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions`；`tsc -p xdg_config/pi/agent/extensions/subagent/tsconfig.json`。
- **预期 capture**：background scout settle 后 idle 行显示类似 `○ #1 scout ⟨bg⟩ · idle · 2s ✓ · holds slot`。
- **风险与回滚**：仅补齐 live widget elapsed 透传；回滚 = revert runtime.ts 两处 `deps.live.settle` 参数改动与本日志追加。

## 2026-08-24 Iteration 4 — completion collapsed 标题补 elapsed

- **现象**：widget 已带 `· Xs ✓`，但 completion 通知的 collapsed 首行仍为 `✓ completed · scout (#1) · task`，无耗时，widget 与通知不一致
- **根因**：`render.ts` 的 `completionEntryText` 仅在 `expanded` 时拼 `runtime ... · Xs`，collapsed 只拼 agent+title+summary
- **改动**：`render.ts:119` 在 collapsed 首行 `agentLabel` 后追加 `· ${formatCountdown(elapsedMs)}`（仅当 `elapsedMs` 为 number），复用既有 `formatCountdown`，不改 expanded 逻辑；`render.test.ts:145` 与 `index.test.ts:916` 同步更新断言
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions` 13 files 206 passed；`tsc -p subagent/tsconfig.json` 绿
- **预期**：collapsed 通知变为 `✓ completed · scout (#1) · 6s · task-title`，expanded 仍 `runtime idle · 6s`
- **风险**：纯展示，标题多 `· Xs`，不影响批处理或 settled 逻辑；回滚 revert 单行

## 2026-08-24 Iteration 5 — capacity error bounded retry context

- **目标**：并发容量耗尽时，父模型收到可操作的重试上下文，而不是只有 `Subagent capacity unavailable: maxConcurrentRuns is 3.` 一句文字。
- **证据**：`index.ts` capacity 分支原仅返回 `{ error }`；`runtime.ts` 已维护 `occupiedSlots` 但未暴露给工具层。
- **改动**：`runtime.ts` 的 `RuntimeHub` 暴露 `occupiedSlots()` / `availableSlots()`；`index.ts` capacity error details 增加 `maxConcurrentRuns`、`occupiedSlots`、`availableSlots` 与 bounded 的 `{index, agent, status}` runtimes 快照，不包含 transcript；`index.test.ts` 覆盖 3 个 idle runtimes 占满后的新错误形状。
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions`；`tsc -p xdg_config/pi/agent/extensions/subagent/tsconfig.json`。
- **预期错误示例**：之前 `{ error: "Subagent capacity unavailable: maxConcurrentRuns is 3." }`；现在 `{ error: "Subagent capacity unavailable: maxConcurrentRuns is 3.", maxConcurrentRuns: 3, occupiedSlots: 3, availableSlots: 0, runtimes: [{ index: 1, agent: "scout", status: "idle" }] }`。
- **风险与回滚**：只丰富错误 details，成功路径不变；回滚 = revert Iteration 5 对 `index.ts` / `runtime.ts` / `index.test.ts` / `EVOLVE_LOG.md` 的改动。

## 2026-08-24 Iteration 6 — auto-evolve daemon observability and control

- **目标**：为 auto-evolve 守护进程补充启动 git diff 快照、忙闲 skip 上下文与 TERM/INT 优雅退出日志，方便审计并避免无人值守时无限打扰。
- **证据**：`auto-evolve.sh` 原仅记录 started / skip 文案，`tmux capture-pane` 的 busy 匹配上下文未落盘；未安装 signal trap；启动日志也没有当前仓库 diff 摘要。
- **改动**：保留 `INTERVAL_SEC=90` 与 10 轮上限；新增 `trap 'handle_signal TERM' TERM` / `trap 'handle_signal INT' INT`；启动时记录 `git -C /Users/liu/tools/dotfiles diff --stat`；每次 busy skip 将匹配到的 `RUNNING TOOLS|STREAMING` capture 行写入 `/tmp/auto-evolve.log`。
- **验证**：`bash -n xdg_config/pi/agent/extensions/subagent/auto-evolve.sh`；`cat xdg_config/pi/agent/extensions/subagent/auto-evolve.sh | grep -E "trap|diff --stat"`；`cat xdg_config/pi/agent/extensions/subagent/EVOLVE_LOG.md | tail`。
- **风险与回滚**：仅增强脚本内部日志与信号处理，不新增依赖、不改变 90s/10 轮行为；回滚 = revert Iteration 6 对 `auto-evolve.sh` 与本日志追加。

## 2026-08-24 Iteration 7 — list exposes evolveLog summary after Iteration 6

- **目标**：让父模型与人通过 `subagent list` 的 structured details 发现 subagent 自进化历史，而不必手动 `cat EVOLVE_LOG.md`。
- **证据**：`index.ts` 的 list 分支原 details 只有 `agents` 与 `discoveryErrors`；`EVOLVE_LOG.md` 已记录 Iteration 1-6。
- **改动**：`index.ts` list 分支 best-effort 读取本目录 `EVOLVE_LOG.md`，在存在标题时追加 bounded `evolveLog: { iterations, lastIteration, path }`；读取失败静默忽略，不影响 agent discovery；`index.test.ts` 增加 list details 摘要断言。
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions`；`tsc -p xdg_config/pi/agent/extensions/subagent/tsconfig.json`。
- **风险与回滚**：只增加 list details 字段且保持 `isError=false`；回滚 = revert Iteration 7 对 `index.ts` / `index.test.ts` / `EVOLVE_LOG.md` 的改动。

## 2026-08-24 Iteration 8 — list exposes auto-evolve daemon state

- **目标**：让父模型通过 `subagent list` 的 structured details 判断 auto-evolve 守护是否仍在无人值守自驱中，而不必手动读取 `/tmp/auto-evolve.log`。
- **证据**：Iteration 7 只暴露 `evolveLog`；daemon 活跃态、最后心跳与已观察 iter 仍需 `cat /tmp/auto-evolve.log`。
- **改动**：`index.ts` list 分支 best-effort 读取 `/tmp/auto-evolve.log` 尾部 4k / 50 行，存在时追加 bounded `daemon: { active, lastHeartbeat, iterationsObserved }`；`active` 由最后时间戳距当前 5 分钟内判定；读取失败静默忽略且不改 `agents` / `evolveLog`。
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions`。
- **风险与回滚**：只增加 list details 字段且保持 `isError=false`；回滚 = revert Iteration 8 对 `index.ts` 与 `EVOLVE_LOG.md` 的改动。

## 2026-08-24 Iteration 9 — daemon active parsing boundary

- **目标**：让 `subagent list` 的 daemon active 判定在最后心跳缺失/格式异常时稳定回落 inactive，并让 iter 观测计数容忍大小写与多余空格。
- **证据**：Iteration 8 的 `active` 由 tail 内最后一个可解析时间戳决定；若最后一行没有有效时间戳，旧时间戳仍可能让 daemon 误显示 active；`iterationsObserved` 只匹配小写 `=== iter`。
- **改动**：`index.ts` 仅解析最后非空日志行的 ISO 时间戳，解析失败时 `active=false`；`iterationsObserved` 改为大小写不敏感并允许 `===   ITER` 这类空格变体；保持 `/tmp/auto-evolve.log` 尾部 4k / 50 行读取、5 分钟窗口、best-effort 与 `isError=false` 不变。
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions`。
- **风险与回滚**：只收紧 daemon 状态摘要边界；回滚 = revert Iteration 9 对 `index.ts` / `index.test.ts` / `EVOLVE_LOG.md` 的改动。

## 2026-08-24 Iteration 10 — 稳定收官与回滚总览

- **目标**：收官自进化 10 轮，固化“每轮小步、可验证、可单文件回滚”的迭代契约；不引入新功能，保留后续演进入口。
- **10 轮总览**：1 live-ui idle elapsed；2 idle outcome 着色；3 runtime elapsed 透传；4 completion collapsed 耗时；5 capacity retry context；6 daemon 启动/skip/trap 可观测；7 list 暴露 evolveLog；8 list 暴露 daemon 状态；9 daemon active 解析边界；10 稳定收官与重启指引。
- **验证总览**：收官检查固定为 `bash -n xdg_config/pi/agent/extensions/subagent/auto-evolve.sh` 与 `npm test --prefix xdg_config/pi/agent/extensions -- subagent`；list 仍应感知 `evolveLog.iterations >= 9` 且 `isError=false`。
- **全局回滚点**：每轮按日志中列出的文件做单文件 revert；本轮只需 revert `EVOLVE_LOG.md` 追加段、`auto-evolve.sh` 收官日志块，以及可选测试断言调整。
- **收官日志与重启**：`auto-evolve.sh` 达到 10 轮上限时会写入已完成 10 轮、当前 `git diff --stat` 摘要与重启命令；如需再次启动：`nohup bash xdg_config/pi/agent/extensions/subagent/auto-evolve.sh >/tmp/auto-evolve.out 2>&1 &`。
- **风险与回滚**：仅日志/守护脚本收官提示/测试阈值，不改 live-ui/render/runtime 核心；失败回滚 = revert 本轮三个 bounded 文件改动。
