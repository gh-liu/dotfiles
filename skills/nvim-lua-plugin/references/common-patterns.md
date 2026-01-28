# 常见代码模式（Best Practice Snippets）

本文收集 Neovim Lua 插件开发中的常见模式，可直接复制使用。

## 模式 1：安全可选依赖

当插件功能依赖其他插件时，应优雅处理缺失情况：

```lua
-- 不推荐：直接 require，插件未安装会报错
local telescope = require('telescope')
telescope.builtin()

-- 推荐：pcall + 提示用户
local ok, telescope = pcall(require, 'telescope.builtin')
if not ok then
  vim.notify('telescope.nvim not found. Some features will be unavailable.', vim.log.levels.WARN)
  return
end
telescope.find_files()
```

## 模式 2：用户配置与默认值合并

```lua
local M = {}

local defaults = {
  max_width = 80,
  timeout = 5000,
  mappings = {
    close = '<Esc>',
    submit = '<CR>',
  }
}

-- 用户只需覆盖需要的字段
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
end
```

## 模式 3：Namespace 注册与清理

```lua
local M = {}

-- 创建唯一的 namespace（避免冲突）
local ns_id = vim.api.nvim_create_namespace('myplugin-highlight')

-- 使用 namespace 标记
function M.highlight(bufnr, start, end_)
  vim.api.nvim_buf_set_extmark(bufnr, ns_id, start, 0, {
    end_line = end_,
    hl_group = 'MyPluginHighlight',
  })
end

-- 清理所有标记
function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end
```

## 模式 4：Buffer-local 状态与 autocmd 清理

```lua
local M = {}
local bufnr_state = {}

function M.attach(bufnr)
  bufnr_state[bufnr] = { active = true }

  -- 使用 buffer-local autocmd，buffer 关闭时自动清理
  local augroup = vim.api.nvim_create_augroup('MyPlugin' .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd('BufUnload', {
    buffer = bufnr,
    group = augroup,
    callback = function()
      bufnr_state[bufnr] = nil
    end,
  })
end
```

## 模式 5：避免重复初始化

```lua
local M = {}
local initialized = false

function M.setup(opts)
  if initialized then
    vim.notify('myplugin already initialized. Use setup() only once.', vim.log.levels.WARN)
    return
  end
  initialized = true

  -- 初始化逻辑...
end

-- 或者用元表保护（更严格）
local M = {}
local config = {}

setmetatable(M, {
  __newindex = function(t, k, v)
    if k == 'config' then
      if rawget(t, 'config') ~= nil then
        error('myplugin.config is read-only after setup')
      end
      rawset(t, k, v)
    else
      rawset(t, k, v)
    end
  end
})
```

## 模式 6：延迟加载大型模块

```lua
-- plugin/myplugin.lua

-- 不推荐：顶层 require
-- local parser = require('myplugin.parser')  -- 启动时加载

-- 推荐：闭包缓存
local parser
local function get_parser()
  if not parser then
    parser = require('myplugin.parser')
  end
  return parser
end

vim.api.nvim_create_user_command('MyPluginParse', function()
  -- 只在命令执行时加载
  get_parser().parse()
end, {})
```

## 模式 7：浮动窗口最佳实践

```lua
local M = {}

function M.open_float()
  -- 计算合适的窗口尺寸
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(20, vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- 创建 buffer
  local bufnr = vim.api.nvim_create_buf(false, true)  -- 临时、scratch

  -- 创建窗口
  local winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  })

  -- 设置 buffer 选项
  vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(bufnr, 'filetype', 'myplugin')

  -- 窗口关闭时清理
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(winnr),
    once = true,
    callback = function()
      -- 清理逻辑...
    end,
  })

  return winnr, bufnr
end
```

## 模式 8：类型注解（LuaLS / EmmyLua）

```lua
---@class MyPluginConfig
---@field enabled boolean
---@field max_width integer
---@field timeout integer
---@field mappings table<string, string>

---@class MyPlugin
---@field config MyPluginConfig
local M = {}

---@param opts? MyPluginConfig
function M.setup(opts)
  -- setup 逻辑
end

---@return string[]
function M.get_items()
  return { 'a', 'b', 'c' }
end

return M
```

## 模式 9：异步操作（使用 lua-libuv）

```lua
local M = {}

-- 不推荐：同步读取大文件会阻塞 UI
-- local content = vim.fn.readfile('large-file.txt')

-- 推荐：使用 uv.fs_open + uv.fs_read
function M.read_async(path, callback)
  uv.fs_open(path, 'r', 438, function(err_open, fd)
    if err_open then return callback(nil, err_open) end

    uv.fs_fstat(fd, function(err_stat, stat)
      if err_stat then return callback(nil, err_stat) end

      uv.fs_read(fd, stat.size, 0, function(err_read, data)
        uv.fs_close(fd, function() end)  -- 总是关闭 fd
        if err_read then return callback(nil, err_read) end
        callback(data)
      end)
    end)
  end)
end
```

## 模式 10：命令参数解析

```lua
-- 支持范围、count、bang、参数
vim.api.nvim_create_user_command('MyPlugin', function(opts)
  -- opts.range: 0=无范围, 1=单行, 2=全范围
  if opts.range == 1 then
    local line = vim.api.nvim_get_current_line()
    -- 处理单行...
  elseif opts.range == 2 then
    local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
    -- 处理范围...
  end

  -- opts.count: 用户指定的 count
  local count = opts.count or 1

  -- opts.bang: 是否有 !
  local force = opts.bang

  -- opts.fargs: 参数列表
  -- opts.args: 原始参数字符串
  for _, arg in ipairs(opts.fargs) do
    -- 处理参数...
  end
end, {
  range = true,    -- 支持 range
  count = true,   -- 支持 count
  bang = true,    -- 支持 !
  nargs = '*',    -- 参数个数：0、1 或 *（任意）、?（0-1）、+（1+）
  complete = function(arg, cmd_line)
    -- 自定义补全
    return { 'option1', 'option2', 'option3' }
  end,
})
```
