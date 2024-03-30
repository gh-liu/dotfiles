if false then
	return
end

local api = vim.api
local ts = vim.treesitter
local fn = vim.fn

local M = {}

local function get_closest_func()
	local parser = ts.get_parser()
	local tree = parser:trees()[1]
	local query = ts.query.get("go", "funcname")
	query:iter_matches(tree:root(), 0, 0, api.nvim_win_get_cursor(0)[1])

	local nearest_match
	-- from line 0 to cursor
	for _, match, _ in query:iter_matches(tree:root(), 0, 0, api.nvim_win_get_cursor(0)[1]) do
		nearest_match = match
	end

	local type, func, struct
	for id, node in pairs(nearest_match) do
		local capture = query.captures[id]
		if capture == "func" or capture == "method" then
			type = capture
			func = ts.get_node_text(node, 0)
		end
		if capture == "type" then
			struct = ts.get_node_text(node, 0)
		end
	end

	return type, func, struct
end

local function append_test_func_name(test, str)
	if str:sub(1, 1):match("%u") ~= nil then
		test = test .. str
	else
		test = test .. "_" .. str
	end
	return test
end

--[[ 
funcName -> Test_funcName 
FuncName -> TestFuncName
]]
---@param func string
---@return string
local function generate_func_name(func)
	return append_test_func_name("Test", func)
end

--[[ 
StructName.MethodName -> TestStructNameMethodName
StructName.methodName -> TestStructName_methodName
structName.MethodName -> Test_structNameMethodName
structName.methodName -> Test_structName_methodName 
]]
---@param struct string
---@param func string
---@return string
local function generate_method_name(struct, func)
	return append_test_func_name(append_test_func_name("Test", struct), func)
end

local function generate_test(func_name)
	local template = [[
func %s(t *testing.T) {
	testCases := []struct {
		desc string
	}{
		{
			desc: "",
		},
	}
	for _, tC := range testCases {
		t.Run(tC.desc, func(t *testing.T) {
		})
	}
}
	]]
	return string.format(template, func_name)
end

local function bufwinid(bufnr)
	for _, win in ipairs(api.nvim_list_wins()) do
		if api.nvim_win_get_buf(win) == bufnr then
			return win
		end
	end
end

--- jump to line
---@param opts? {reuse_win: boolean, focus:boolean}
local function jump_to_line(bufnr, row, opts)
	local opts = opts or {}
	local reuse_win = opts.reuse_win or false
	local focus = opts.focus or false
	if focus then
		-- Save position in jumplist
		vim.cmd("normal! m'")

		-- Push a new item into tagstack
		local from = { fn.bufnr("%"), fn.line("."), fn.col("."), 0 }
		local items = { { tagname = fn.expand("<cword>"), from = from } }
		fn.settagstack(fn.win_getid(), { items = items }, "t")
	end

	local win = reuse_win and bufwinid(bufnr) or focus and api.nvim_get_current_win()

	vim.bo[bufnr].buflisted = true
	api.nvim_win_set_buf(win, bufnr)
	if focus then
		api.nvim_set_current_win(win)
	end

	if row < 0 then
		row = api.nvim_buf_line_count(bufnr) + row
	end
	api.nvim_win_set_cursor(win, { row, 0 })
	api.nvim_win_call(win, function()
		-- Open folds under the cursor
		vim.cmd("normal! zv")
	end)
end

local function test_file_bufnr()
	local fname = fn.expand("%:p")
	if not fname:match("_test%.go$") then
		fname = fname:gsub("%.go$", "_test.go")
		local bufnr = fn.bufadd(fname)
		fn.bufload(bufnr)
		return bufnr
		-- return vim.uri_to_bufnr(vim.uri_from_fname(fname))
	end
	return 0
end

local function appen_to_file(bufnr, body)
	local lines = vim.split(body, "\n")
	api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
	return #lines
end

local function test_func_linenr(bufnr, func_name)
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for idx, line in ipairs(lines) do
		if line:match("^func " .. func_name .. "%(") then
			return idx
		end
	end
	return 0
end

local function get_closest_testfunc()
	local parser = vim.treesitter.get_parser()
	local tree = parser:trees()[1]
	local query = ts.query.get("go", "testfunc")

	local match
	for _, m, _ in query:iter_matches(tree:root(), 0, 0, api.nvim_win_get_cursor(0)[1]) do
		match = m
	end
	local closest_node, type
	for id, node in pairs(match) do
		local name = query.captures[id]
		if name == "testfuncname" or name == "benchfuncname" or name == "fuzzfuncname" then
			closest_node = node
			type = name
		end
	end

	return vim.treesitter.get_node_text(closest_node, 0), type
end

local run_test = function()
	local Term = require("liu.utils.term").Term
	local term = Term.new()
	local t = term:open({
		dir = fn.expand("%:h"),
		delete_when_close_win = true,
	})
	local cmd = "go test "

	local func_name, type = get_closest_testfunc()
	if type == "testfuncname" then
		cmd = cmd .. "-test.run " .. func_name
	end
	if type == "benchfuncname" then
		cmd = cmd .. "-test.run a^ " .. "-test.bench " .. func_name
	end
	if type == "fuzzfuncname" then
		cmd = cmd .. "-test.run a^ " .. "-test.fuzz " .. func_name
	end

	t:exec(cmd)
end

local gen_or_jump_to_test = function()
	local type, func, struct = get_closest_func()
	local func_name
	if type == "func" then
		func_name = generate_func_name(func)
	end
	if type == "method" then
		func_name = generate_method_name(struct, func)
	end

	if func_name then
		local test_bufnr = test_file_bufnr()
		local linenr = test_func_linenr(test_bufnr, func_name)
		if linenr > 0 then
			jump_to_line(test_bufnr, linenr, { reuse_win = true, focus = true })
			vim.notify(string.format("[Test] jump to `func %s`", func_name), vim.log.levels.INFO)
		else
			local count = appen_to_file(test_bufnr, generate_test(func_name))
			jump_to_line(test_bufnr, -count + 1, { reuse_win = true, focus = true })
			vim.notify(string.format("[Test] generate `func %s`", func_name), vim.log.levels.INFO)
		end
	end
end

M.setup = function()
	local autocmd = api.nvim_create_autocmd
	local augroup = api.nvim_create_augroup
	local g = augroup("liu/go", { clear = true })
	autocmd("BufEnter", {
		group = g,
		pattern = "*.go",
		callback = function(ev)
			local buf = ev.buf
			local is_test = vim.endswith(ev.file, "_test.go")
			if is_test then
				api.nvim_buf_create_user_command(buf, "GoRunTest", function(opts)
					run_test()
				end, {
					desc = "Go: run test",
				})
			else
				api.nvim_buf_create_user_command(buf, "GoTest", function(opts)
					gen_or_jump_to_test()
				end, {
					desc = "Go: generate or jump to test",
				})
			end
		end,
		desc = "Go: run test",
	})
end

M.setup()

-- return M
