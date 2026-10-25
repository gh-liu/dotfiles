-- Run from the Neovim config directory:
-- nvim --headless -u NONE -i NONE -l tests/mermaid.lua
local root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))
local api = vim.api
local namespace = api.nvim_create_namespace("liu/mermaid")
vim.cmd.source(root .. "/after/plugin/mermaid.lua")

local function marks(buf)
	vim.cmd("redraw!")
	return api.nvim_buf_get_extmarks(buf or 0, namespace, 0, -1, { details = true })
end

local function replace(lines)
	api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function code(mark)
	local encoded = assert(mark[4].url:match("^https://mermaid%.ink/svg/base64:(.+)$"))
	encoded = encoded:gsub("-", "+"):gsub("_", "/")
	encoded = encoded .. string.rep("=", (4 - #encoded % 4) % 4)
	return vim.json.decode(vim.base64.decode(encoded)).code
end

vim.bo.filetype = "markdown"
replace({ "```mermaid", "graph TD", "  A[你好] --> B", "```" })
local mark = assert(marks()[1])
assert(#marks() == 1 and mark[2] == 0 and mark[3] == 3 and mark[4].end_col == 10)
assert(code(mark) == "graph TD\n  A[你好] --> B", "Diagram source was changed")
api.nvim_win_set_cursor(0, { 1, 3 })
assert(vim.ui._get_urls()[1] == mark[4].url, "Built-in gx cannot find the URL")
assert(marks()[1][1] == mark[1], "An unchanged redraw recreated the extmark")
vim.cmd.vsplit()
local split = api.nvim_get_current_win()
assert(marks()[1][1] == mark[1], "A second window recreated the buffer's extmarks")
api.nvim_win_close(split, true)

-- Editing the diagram must replace, rather than accumulate, links.
api.nvim_buf_set_lines(0, 2, 3, false, { "  A --> C" })
assert(#marks() == 1 and code(marks()[1]) == "graph TD\n  A --> C")

-- Respect the surrounding fence: an example inside a longer fence is inert.
replace({ "````markdown", "```mermaid", "graph TD; A-->B", "```", "````" })
assert(#marks() == 0, "Rendered a nested example")

-- Both fence styles work; shorter or mismatched fences cannot close a block.
replace({ "  ~~~~ mermaid", "  graph TD", "    A-->B", "  ~~~", "  ```", "  ~~~~~" })
mark = assert(marks()[1])
assert(mark[3] == 7 and code(mark) == "graph TD\n  A-->B\n~~~\n```")

replace({ "```mermaid", "graph TD", "```oops", "```" })
assert(code(marks()[1]) == "graph TD\n```oops", "A closing fence cannot have an info string")
replace({ "```mermaid", "graph TD" })
assert(#marks() == 0, "Unclosed blocks must not get links")
replace({ "```mermaid", "```", "```lua", "print('hi')", "```" })
assert(#marks() == 0, "Empty or non-Mermaid blocks must not get links")
replace({ "```mermaidish", "graph TD", "```" })
assert(#marks() == 0, "The language must match exactly")

replace({ "```mermaid", "graph TD; A-->B", "```", "~~~mermaid", "graph LR; C-->D", "~~~" })
assert(#marks() == 2)
local first = api.nvim_get_current_buf()
vim.cmd.enew()
vim.bo.filetype = "markdown"
replace({ "```mermaid", "graph TD; E-->F", "```" })
assert(#marks() == 1 and #marks(first) == 2, "Buffer namespaces interfered")
vim.bo.filetype = "text"
assert(#marks() == 0, "Changing filetype must remove links")
api.nvim_set_current_buf(first)
replace({ "No diagrams" })
assert(#marks() == 0, "Deleting a diagram left stale links")

-- A hidden buffer is refreshed when it becomes visible, without change events.
api.nvim_buf_set_lines(first, 0, -1, false, { "```mermaid", "graph TD; A-->B", "```" })
marks()
vim.cmd.enew()
api.nvim_buf_set_lines(first, 1, 2, false, { "graph TD; A-->Z" })
api.nvim_set_current_buf(first)
assert(code(marks()[1]) == "graph TD; A-->Z", "A hidden buffer kept a stale URL")

print("Mermaid URL extmark tests passed")
