# Self-Evolution Log

> 规则：通用自进化日志——任何被 pi 自进化循环驱动的工作单元（subagent extension、auto-evolve extension、其它扩展/配置）每次自进化都必须小步、可验证、可回滚，并记录目标、证据、改动、验证、风险。本文件位于 agent/evolve/ 命名空间，由 subagent extension 专属日志提升而来，Iteration 1-10 为 subagent 历史迭代。

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

## Post-review hardening

- `auto-evolve.sh` 现在要求显式 pane ID，动态发现仓库根目录，并在启动、capture 与每次 send 前校验 pane 仍由 Pi runtime（`pi`/`node`/`nodejs`/`bun`）占用且 cwd 位于目标仓库内；原先硬编码 `%0`、`/Users/liu/tools/dotfiles` 与危险的 `yes go` 文本不再使用。
- 模型现在决定何时结束：每轮收到“继续改进或创建本次运行专属 stop signal”的提示；创建 signal 后脚本退出。`SAFETY_MAX_ATTEMPTS`（默认 100）仅是模型失联时的熔断，busy skip 也消耗 attempt。日志默认位于 Pi agent 目录的 `auto-evolve.log`，可通过 `AUTO_EVOLVE_LOG` 覆盖。
- `subagent list` 在 model-facing content 与 structured details 中都返回 bounded evolve/daemon 摘要。Evolve 摘要读取完整但最大 1 MiB 的受控日志，只统计 `Iteration <number>` 标题，因此本文件的其他二级标题不会被误计为迭代。
- 上述说明取代 Iteration 6、8、9、10 中关于固定 `/tmp/auto-evolve.log`、硬编码 pane/repo、`nohup` 重启以及宽松标题计数的历史实现描述。

## 2026-08-25 Iteration 11 — EVOLVE_LOG promoted to a shared agent-level log

- **目标**：将 subagent 专属自进化日志泛化为 agent 级通用日志，不再绑死 subagent，成为任何被 pi 自进化循环驱动的工作单元（subagent、auto-evolve、其它扩展/配置）的统一记录入口。
- **证据**：`EVOLVE_LOG.md` 原位于 `xdg_config/pi/agent/extensions/subagent/`；`index.ts` 通过 `new URL("./EVOLVE_LOG.md", import.meta.url)` 相对读取且 `EVOLVE_LOG_RELATIVE_PATH` 写死为 `xdg_config/pi/agent/extensions/subagent/EVOLVE_LOG.md`。
- **改动**：`git mv` 至 `xdg_config/pi/agent/EVOLVE_LOG.md`（保留历史）；`index.ts` 两处改指向 agent 级通用日志并同步注释；`index.test.ts` 硬断言更新为 11 iterations / Iteration 11 / 新 path；auto-evolve skill+README 契约补充通用日志写入要求。
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions` 全绿（typecheck:subagent/context/auto-evolve 与全部 vitest）；`subagent list` 的 evolveLog 摘要 = 11 iterations / Iteration 11 / 新 path；全仓库 grep 无 `extensions/subagent/EVOLVE_LOG.md` 残留。
- **风险与回滚**：纯路径/文档迁移，不涉及任何运行逻辑；回滚 = `git mv` 回原路径 + revert `index.ts`、`index.test.ts`、auto-evolve 契约改动。

## 2026-08-25 Iteration 12 — auto-evolve daemon drives a configurable target

- **目标**：把 `auto-evolve.sh` 写死的「subagent」驱动目标泛化为 `AUTO_EVOLVE_TARGET` 环境变量，使同一 daemon 能驱动进化任意工作单元（subagent、auto-evolve、其它扩展/配置），与 Iteration 11 的 agent 级通用日志契约对齐。
- **证据**：`auto-evolve.sh:117` 的继续提示写死「请评估 subagent 是否还有高价值、可验证的改进」；`:127` 每 3 轮触发的演示提示也绑定 subagent 的 scout widget；`:138` 重启提示写死相对路径 `xdg_config/pi/agent/extensions/subagent/auto-evolve.sh`。Iteration 11 已把 EVOLVE_LOG 提升为 agent 级通用日志，但 daemon 提示文本仍绑死 subagent。
- **改动**：
  - `auto-evolve.sh` 新增 `AUTO_EVOLVE_TARGET="${AUTO_EVOLVE_TARGET:-subagent}"`（空值回落默认，保持既有行为）；启动日志加入 `target=`；继续提示改为「请评估 ${AUTO_EVOLVE_TARGET} …」；subagent 专属的 scout widget 演示仅在目标为 `subagent` 时触发，否则记录 `skipping the subagent widget demo`；重启提示改用 `$SCRIPT_DIR/auto-evolve.sh` 而非写死路径。
  - `auto-evolve.test.ts` 的 `runScript` harness 透传 `AUTO_EVOLVE_TARGET`，新增 3 个用例：非 subagent 目标的继续提示、默认目标的 widget 演示仍触发、非 subagent 目标跳过演示。
  - `subagent/index.test.ts` evolveLog 硬断言 11 → 12 iterations / Iteration 12（本小节使断言过期，按契约同步）。
- **验证**：`bash -n xdg_config/pi/agent/extensions/subagent/auto-evolve.sh`；`npm test --prefix xdg_config/pi/agent/extensions` 全绿。
- **风险与回滚**：仅提示文本与演示门控变化，不改变 90s/100 轮/stop-file 协议；默认值保持 `subagent`，未设置环境变量时行为与之前完全一致；回滚 = revert `auto-evolve.sh`、`auto-evolve.test.ts`、`index.test.ts` 与本 EVOLVE_LOG.md 追加段。

## 2026-08-25 Iteration 13 — reload 后观测摘要只反映当前轮次捕获

- **目标**：修复 daemon 在 `/reload` 后打印观测摘要时，用 `grep "$LOG"` 匹配**整个累计日志**、`tail -n 5` 可能命中更早轮次旧文本的问题，使摘要只反映本轮刚捕获的当前 pane 状态。
- **证据**：`auto-evolve.sh` 原 `capture_pane | tail -n 30 >> "$LOG"` 后接 `grep -E "Reloaded|idle|holds|✓|✗" "$LOG" | tail -n 5`；`grep` 作用对象是已累积的单一日志文件，同一文件里的旧轮次匹配行也会进入 `tail -n 5`，导致「capture after reload」与实际 pane 状态可能不符。
- **改动**：将 capture 先存入 `fresh_capture` 变量并 `>> "$LOG"` 落盘，再用 `grep ... <<< "$fresh_capture"` 仅对**本轮**捕获匹配；busy skip 与 demo 的调试分支（本就 `<<< "$pane_snapshot"`）不受影响。`AUTO_EVOLVE_TARGET`、90s/100 轮、stop-file 协议不变。本小节使 `subagent/index.test.ts` evolveLog 硬断言 12 → 13 同步过期，按契约更新。
- **验证**：`bash -n xdg_config/pi/agent/extensions/subagent/auto-evolve.sh`；`npm test --prefix xdg_config/pi/agent/extensions` 全绿。
- **风险与回滚**：仅影响日志观测摘要的匹配来源，不影响任何 send/reload/stop 逻辑；回滚 = revert 本轮对 `auto-evolve.sh` 的单行替换与本 EVOLVE_LOG.md 追加段。

## 2026-08-25 Iteration 14 — auto_evolve_status 收敛 logTail 上下文预算

- **目标**：收敛 `auto_evolve_status` 结构化 details 中每个 pane 的 `logTail` 快照（原最高 8KB/pane），避免父模型反复轮询监控时被完整日志尾部撑大上下文；完整 daemon 日志仍在 `logPath` 可深读。
- **证据**：`index.ts` status 工具对每个候选 pane 调用 `daemonStatus`，其 `readLogTail` 默认读取最后 8KB；2 个 pane 的 status details 最高携带 ~16KB 日志。skill/README 已约定「读 daemon 日志文件获得完整细节」，logTail 主要只是即时快照。
- **改动**：`daemon.ts` 给 `daemonStatus` 增加可选 `logTailMaxBytes`（默认 `DEFAULT_DAEMON_LOG_TAIL_BYTES=8KB`，向后兼容）并透传给 `readLogTail`；`index.ts` status 工具传入 `STATUS_LOG_TAIL_MAX_BYTES=2KB` 的有界预算。新增两个单测：daemon 单元覆盖 `logTailMaxBytes` 截断，status 工具覆盖每个候选 pane 都以 2KB 预算调用 `readLogTail`。本小节使 `subagent/index.test.ts` evolveLog 硬断言 13 → 14 同步过期，按契约更新。
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions` 全绿（typecheck + vitest 含新增用例）。
- **风险与回滚**：仅收敛 status 快照字节上限，不改变 active/lastHeartbeat 判定、start/stop 逻辑、日志写入；默认 8KB 未变，仅 status 工具显式收紧到 2KB；回滚 = revert `daemon.ts`、`index.ts`、两个测试文件与 EVOLVE_LOG.md 追加段。
## 2026-08-25 Iteration 15 — auto-evolve daemon relocated into its own extension

- **目标**：解除 auto-evolve 机制与 subagent 的物理耦合，把 `subagent/auto-evolve.sh` 与 `subagent/auto-evolve.test.ts` 迁移到 `extensions/auto-evolve/`，让脚本与测试随 daemon 归位到 auto-evolve extension，消除跨目录相对路径依赖。
- **证据**：Iteration 11 已把 EVOLVE_LOG 提升为 agent 级通用日志、Iteration 12 已把驱动目标与重启提示泛化，但 `daemon.ts:24` 仍通过 `new URL("../subagent/auto-evolve.sh", import.meta.url)` 引用 subagent 目录；`index.ts` 工具描述、`README.md`、`skill/SKILL.md`、`probe.ts` 注释仍写死 `subagent/auto-evolve.sh`。
- **改动**：`git mv` 两文件至 `extensions/auto-evolve/`；`daemon.ts` 注释与 `scriptPath` URL 改为 `new URL("./auto-evolve.sh", import.meta.url)`；`index.ts` 两处工具描述文本去掉 `subagent/` 前缀；`README.md`/`SKILL.md`/`probe.ts` 文案同步改为 `auto-evolve.sh`；`AGENT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"` 与 `pgrep -f "auto-evolve.sh <paneId>"` 在新位置自然成立，无需改动。
- **验证**：`bash -n xdg_config/pi/agent/extensions/auto-evolve/auto-evolve.sh`；`npm test --prefix xdg_config/pi/agent/extensions` 全绿（typecheck + vitest，auto-evolve.test.ts 移动后仍被发现并全部通过）；grep 无 `subagent/auto-evolve` 代码引用残留。
- **风险与回滚**：纯位置迁移与文案变化，无行为变化；回滚 = git mv 回原路径 + revert 文案改动与本次日志追加。

## 2026-08-25 Iteration 16 — drop subagent's auto-evolve daemon observability

- **目标**：移除 subagent 对 auto-evolve daemon 的观测集成，职责完全交还 auto-evolve extension 的 `auto_evolve_status`，subagent 零 auto-evolve 残留。
- **证据**：`subagent/index.ts` 仍含 `summarizeAutoEvolveDaemon`、`readTextTail`、`AUTO_EVOLVE_DAEMON_ACTIVE_MS`、`autoEvolveLogPath` option，list 分支仍汇报 Auto-evolve daemon 状态，与 auto-evolve extension 的 status tool 职责重复。
- **改动**：删除上述函数/常量/option、list 分支的 daemon 字段与相关测试；保留已泛化的 evolveLog 摘要（`readEvolveLog`/`summarizeEvolveLog`/`EVOLVE_LOG_RELATIVE_PATH` 与 list 的 evolveLog 字段、`Evolution: ...` 行）。
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions` 全绿（typecheck:subagent/context/auto-evolve + vitest）；`grep -rni "auto.evolve" xdg_config/pi/agent/extensions/subagent/` 无 auto-evolve daemon 观测代码残留。
- **风险与回滚**：仅移除冗余观测，evolveLog 摘要不变；回滚 = revert `subagent/index.ts`、`subagent/index.test.ts`、`EVOLVE_LOG.md` 改动。

## 2026-08-25 Iteration 17 — subagent drops all evolve responsibilities; evolveLog moves to auto_evolve_status

- **目标**：subagent 零 evolve 残留，自进化状态唯一出口为 auto-evolve 的 `auto_evolve_status`；Iteration 16 已移除 daemon 观测，本迭代移除 subagent 最后的 evolveLog 摘要。
- **证据**：`subagent/index.ts` 仍含 `readEvolveLog`/`summarizeEvolveLog`/`EVOLVE_LOG_RELATIVE_PATH`/`EVOLVE_LOG_MAX_BYTES` 并读取 agent 级 EVOLVE_LOG 向父模型汇报；auto-evolve 的 status tool 尚无 evolveLog 摘要；`subagent/spec.md` 仍提及 evolution-log summary。
- **改动**：
  - 删除 subagent 的 `summarizeEvolveLog`/`readEvolveLog`/`EVOLVE_LOG_*` 与 node:fs import、list 分支的 evolveLog 字段与 `Evolution: ...` 行、相关测试、spec 句。
  - auto-evolve `daemon.ts` 新增 `readEvolveLog`/`summarizeEvolveLog`（path 字段返回常量相对路径），`index.ts` status tool 增加 evolveLog 摘要（details 字段 + content 前缀行）并新增 `options.evolveLogPath` 注入（缺省 `../../EVOLVE_LOG.md` 从 auto-evolve/index.ts 解析到 agent 级日志）。
- **验证**：`npm test --prefix xdg_config/pi/agent/extensions` 全绿（typecheck:subagent/context/auto-evolve + vitest）；`grep -rni "evolve" xdg_config/pi/agent/extensions/subagent/ --include="*.ts"` 无残留；`npx tsc -p auto-evolve/tsconfig.json` 与 `npx tsc -p subagent/tsconfig.json` 通过。
- **风险与回滚**：仅职责迁移——subagent list 去掉一个可选字段、`auto_evolve_status` 增加一个可选字段（缺失时回落现状）；回滚 = revert Part A/B/C 改动并恢复 subagent 旧 evolveLog 逻辑或作为 fallback。

## 2026-08-25 Iteration 18 — self-evolution namespace lands in agent/evolve/

- **目标**：用目录表达自进化体系身份，evolve/ 命名空间归正，不再叫 Subagent 日志；单一日志承载所有被驱动对象，不按对象分日志
- **证据**：EVOLVE_LOG.md 虽已在 agent 根但标题仍是 # Subagent 自进化日志，语义归属与 subagent 强耦合；auto-evolve 机制代码受 pi 扩展发现机制限制须留在 extensions/auto-evolve/
- **改动**：git mv EVOLVE_LOG.md → evolve/；index.ts 与 daemon.ts 两处路径引用更新；新增 evolve/README.md 契约；历史 Iteration 1-17 内容不动
- **验证**：npm test 全绿；node 验证 `../../evolve/EVOLVE_LOG.md` 解析正确；grep 无旧路径代码残留
- **风险与回滚**：纯位置与命名迁移，不改机制行为；回滚 = git mv 回 + revert 引用/README/日志追加段

## 2026-08-25 Iteration 19 — daemon immune to self-rewrite while running

- **目标**：修复无人值守 daemon 被「自身」的进化修改杀死的生产 bug——bash 对脚本是流式读取执行，当被驱动目标恰好是 daemon 脚本本身时，工作区 auto-evolve.sh 在运行中被并发改写会让 bash 崩溃（实测 `auto-evolve.sh: line 134: syntax error near unexpected token 'then'`），daemon 静默终止、stop file 残留、无人值守循环中断。要求用最小充分方案使 daemon 对自身脚本被并发修改免疫。
- **证据**：`auto-evolve.sh` 原在 `set -euo pipefail` 后直接开始定义 SCRIPT_DIR 并进入循环体，任何运行中的脚本改写都可能打断流式读取；上一轮实测崩溃行 134 位于 for 循环体内。`daemon.ts` 通过 `pgrep -f "auto-evolve.sh <pane>"` 发现/停止 daemon，因此快照文件名不能改变 `auto-evolve.sh <pane>` 的匹配形态。
- **改动**：
  - `auto-evolve.sh` 顶部（任何真实工作前）新增自快照块：`cp -- "${BASH_SOURCE[0]}" <snapshot>` 后 `exec bash <snapshot> "$@"`；此后 daemon 执行快照，工作区脚本可被自由修改。快照目录可注入 `AUTO_EVOLVE_SNAPSHOT_DIR`（默认 `${TMPDIR:-/tmp}/auto-evolve-snapshot/<pid>/`，EXIT trap 清理 per-run 目录）。快照保留基名 `auto-evolve.sh`，保证 `pgrep -f "auto-evolve.sh <pane>"` 仍能发现进程（实测快照 cmdline 匹配）。`SCRIPT_DIR`/`AGENT_DIR` 经 `AUTO_EVOLVE_SCRIPT_DIR` env 钉住，RUN_ID/STOP_FILE/LOG 锚定原进程不偏移；90s/100 轮/stop-file 协议语义不变；`AUTO_EVOLVE_SNAPSHOTED=1` 可跳过 re-exec。
  - `auto-evolve.test.ts` 新增 `launchWorkspaceCopy`（临时工作区脚本副本 + fake tmux + 异步 spawn）与 2 个并发改写回归测试，覆盖两种进程生命周期：①多轮循环中途改写（跨轮）；②启动后立即改写（单轮长间隔）。断言无 syntax error、退出码 0、轮次跑满、日志不含被改写内容。`runScript` 注入 `AUTO_EVOLVE_SNAPSHOT_DIR` 到测试临时目录。
  - `README.md` 补充 Self-snapshot immunity 设计决策。
- **验证**：`bash -n extensions/auto-evolve/auto-evolve.sh` OK；`npm test --prefix extensions` 全绿（typecheck:subagent/context/auto-evolve + vitest 17 files/261 tests，含新增 2 用例）；真实还原试验：工作区副本 daemon 运行 1.2s 后写入半截坏脚本，daemon 仍跑完 2 轮退出码 0、pgrep 能发现快照进程、TERM 时 graceful 退出并清理快照。
- **风险与回滚**：re-exec 仅发生在最顶部一次性 cp+exec，环境变量全部透传，未改变任何运行协议；快照默认在 tmp 且 EXIT trap 清理，不污染仓库；唯一代价是每次启动多一次 cp（数 KB，微秒级）。回滚 = revert `auto-evolve.sh` 顶部快照块、`auto-evolve.test.ts` 新增块、`README.md` 对应小节与本日志追加段。
