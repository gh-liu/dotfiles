# 使用 mini.test 为 Neovim 插件写测试（推荐流程）

本文件将 `mini.test` 的核心工作流整理成"插件作者视角"的最小闭环：组织用例 → 运行与筛选 → 使用 child Neovim 做可靠测试 → 选择 reporter → 可选截图测试。

参考文档：
- [mini.test README](https://github.com/nvim-mini/mini.test)
- `:h MiniTest`（vimdoc）

## 关键能力与边界

`mini.test` 适合写"真实插件行为"的测试：

- 用例是 **test set** 中的可调用字段，支持层级组织、hooks、参数化、过滤、reporter 等（见 `:h MiniTest` 的 "Workflow" 与 `MiniTest.new_set()`）。
- 推荐用 **child Neovim** 进程做隔离与可复现（`MiniTest.new_child_neovim()`）。
- 支持 screen/screenshot（`MiniTest.expect.reference_screenshot()`）。

它刻意不做的事：

- **不支持并行执行**。
- 不强调 mocks/stubs：推荐直接在 child 进程里覆盖/重置（见 vimdoc "What it doesn't support"）。

## 推荐目录结构（面向插件仓库）

```
tests/
  test_smoke.lua
  test_commands.lua
scripts/
  minitest.lua
```

默认配置会在 `tests/` 里收集 `test_*.lua`（见 README 的默认 config / `MiniTest.config.collect.find_files`）。

## 写测试：以 "test set + child" 为核心

最低成本的写法是每个文件返回一个 test set：

```lua
local MiniTest = require('mini.test')

local T = MiniTest.new_set()

-- 可以在 hooks 里统一 start/stop child
local child = MiniTest.new_child_neovim()

T['setup'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'scripts/minimal_init.lua' })
    end,
    post_once = function()
      child.stop()
    end,
  },
})

T['setup']['loads without error'] = function()
  child.lua([[require('myplugin')]])
  -- 没抛异常就算 pass
end

T['setup']['command exists'] = function()
  child.lua([[require('myplugin')]])
  local cmds = child.api.nvim_get_commands({})
  MiniTest.expect.equality(cmds['MyPluginCmd'] ~= nil, true)
end

return T
```

建议每个 case：

- `child.start()` 或 `child.restart()` → 设置 runtimepath/加载插件 → 执行操作 → `MiniTest.expect.*`
- `child.stop()`（或在 hooks 里统一处理）

## 运行测试：collect + execute

`mini.test` 的运行分两步（vimdoc "Workflow"）：

- **Collect**：收集并展开参数化用例，必要时过滤。
- **Execute**：按顺序执行 hooks 和 test action，reporter 持续输出。

常用入口：

- `MiniTest.run()`：跑整个项目
- `MiniTest.run_file(file)`：只跑某个文件
- `MiniTest.run_at_location({file=..., line=...})`：跑覆盖某个位置的 case

## reporter（交互 vs CI）

vimdoc 说明了两类默认 reporter：

- `MiniTest.gen_reporter.buffer()`：交互式（打开 buffer 展示进度）
- `MiniTest.gen_reporter.stdout()`：headless/CI（写 stdout）

通常：

- 本地开发用 buffer reporter。
- CI 用 stdout reporter，并让 Neovim headless 运行。

## busted 风格（可用但不建议依赖）

`mini.test` 可以临时 emulate busted 接口（`describe`/`it` 等），但 vimdoc 提醒更稳定的是用它原生的 `MiniTest.new_set()` + 显式 table 字段方式。

## 截图测试（UI 场景）

当你的插件有自定义 UI buffer/窗口时，可以用：

- `MiniTest.new_child_neovim()` 启动 child
- 在 child 里执行 UI 操作
- `child.get_screenshot()` + `MiniTest.expect.reference_screenshot()` 做回归

截图会自动保存在 `tests/screenshots/` 下，方便 git diff 检测 UI 变化。

## 典型 CI 脚本（GitHub Actions 示例）

```yaml
- name: Run tests
  run: |
    nvim --headless -u scripts/minimal_init.lua \
      -c "lua require('mini.test').run({ execute = { reporter = require('mini.test').gen_reporter.stdout() } })"
```
