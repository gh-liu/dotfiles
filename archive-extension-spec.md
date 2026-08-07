# Pi `/archive` Physical Branch Archive Extension

## 1. Outcome

`/archive` 是纯 Extension 实现的 branch lifecycle manager，不修改或替换 Pi Core 的原生
`/tree` 命令。

用户语义：

- Space archive：从 active session JSONL 物理提取整个 branch subtree。
- Archive 后：subtree 不再存在于 Pi 原生 session tree，因此原生 `/tree` 不显示它。
- Space restore：把 subtree 的原始 entries 精确写回 session JSONL。
- Enter archived branch：restore 后跳转到保存的 preferred resume point。
- 恢复后：原生 `/tree` 再次显示原 branch，并可继续 conversation。

只展示产生分支的节点：`/archive` UI 从 logical tree 派生 branch roots，不枚举所有 messages。

## 2. Constraints

- 只能使用 Pi Extension API 和 session 文件；不修改 Pi Core。
- 不注册 `/tree`，不拦截、不重定向、不替换原生 `/tree`。
- 不修改被归档 entry 的 `id`、`parentId`、`timestamp`、`content` 或原始 JSON line。
- 不删除历史：归档内容保存在 session 内的 `branch-archive` physical event payload 中。
- 一次只允许一个尚未恢复的 physical archive。
- 只允许 archive logical branch root：其 logical parent 必须拥有多个 logical children。
- Legacy metadata-only events（没有 `version: 1`）只作为历史数据，不代表 physical archive。

## 3. Storage Model

Archive event 使用 `customType: "branch-archive"`，payload 包含：

- `version: 1`
- transaction/session/root/resume IDs
- archive timestamp
- original session digest and retained-entry digest
- original entry count
- subtree 每个 entry 的 original ordinal、raw JSON line 和 SHA-256 digest

Archive transaction 在一次 atomic replacement 中同时完成：

1. 严格读取和校验 session JSONL。
2. 计算 physical subtree closure。
3. 从 active records 中移除 subtree。
4. 追加包含完整恢复 payload 的 archive event。
5. 在 session 同目录写 temp file 并 `fsync`。
6. 重新校验源文件 snapshot 未变化。
7. 创建 backup 后 atomic rename，并 `fsync` parent directory。
8. 通过 `switchSession(samePath)` 重新加载，验证后删除 backup。

Restore transaction 在一次 atomic replacement 中：

1. 校验 archive event、session ID、record digests 和 live ID conflicts。
2. 按 original ordinal 恢复所有 raw entries。
3. 保留 archive event，并追加对应的 versioned restore event 关闭 active archive。
4. atomic replace、重新加载、验证，然后按 `resumeId` navigation。

## 4. Safety Model

Pi 0.84 没有暴露 session transaction 或跨进程文件锁，因此 Extension 无法完全消除另一个
Pi 进程在最终 snapshot check 与 rename 之间写入的 TOCTOU race。

实现采用以下边界：

- 仅在 `ctx.isIdle()` 且没有 pending messages 时运行。
- 要求 persisted session file。
- 假设同一 session 由单个 Pi writer 独占。
- rename 前校验 digest、inode、size 和 mtime。
- malformed JSON、missing parent、cycle、duplicate ID、invalid reference、digest mismatch、
  stale snapshot 或 corrupted event 全部 fail closed。
- switch/reload 验证失败时保留 `.bak`，不宣称 transaction 已安全完成。

用户不应在两个 Pi 进程中同时打开并写同一个 session 后执行 Archive/Restore。

## 5. UI

`/archive`：

```text
↑↓       navigate
←→       collapse / expand archived subtree
Space    archive / restore exact branch root
Enter    navigate, or restore + navigate
Esc      close
```

Archive payload 中的 entries 会仅在 `/archive` 内存 projection 中 materialize，使 archived root
仍可管理；它们不写回 active tree，所以原生 `/tree` 保持隐藏状态。

## 6. Invariants

1. Archive 后 native `SessionManager.getTree()` 不包含 archived subtree IDs。
2. Restore 后 native tree 再次包含这些 IDs。
3. Restore 的 original record prefix 与 archive 前逐行一致。
4. Archive/Restore event 与对应 JSONL topology change 位于同一次 atomic replacement。
5. Corrupted payload 不会被当作 legacy metadata 忽略，而是显式报错。
6. Extension 不注册或修改 `/tree`。
