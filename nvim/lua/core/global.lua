_G.as = {}

local cmd = vim.api.nvim_command

-- create global variables for config file
--
-- local ok, config = pcall(require, "config")
-- if ok then
-- 	for k, v in pairs(config) do
-- 		local key = "self_" .. k
-- 		if not vim.g[key] then
-- 			if string.match(k, "themes") then
-- 				vim.g[k] = v
-- 			end
-- 			vim.g[key] = v
-- 		end
-- 	end
-- end

-- options
--
function as.opt(o, v, scopes)
	scopes = scopes or { vim.o }
	for _, s in ipairs(scopes) do
		s[o] = v
	end
end

-- mappings
--
function as.map(modes, lhs, rhs, opts)
	local options = { noremap = true, silent = true }
	if opts then
		options = vim.tbl_extend("force", options, opts)
	end

	if type(modes) == "string" then
		modes = { modes }
	end

	for _, mode in ipairs(modes) do
		vim.api.nvim_set_keymap(mode, lhs, rhs, options)
	end
end

-- autocommands
--
local function autocmd(this, event, spec)
	local pattern = "*"
	local action = spec
	local ev = event
	local args = {}

	if type(spec) == "table" then
		pattern = spec[1] or pattern
		action = spec[2] or action
		if #spec > 2 then
			args = vim.tbl_extend("force", args, spec[3])
		end
	end

	if type(action) == "function" then
		action = this.set(action, args)
	end

	ev = type(ev) == "table" and table.concat(ev, ",") or ev

	pattern = type(pattern) == "table" and table.concat(pattern, ",") or pattern

	cmd("autocmd " .. ev .. " " .. pattern .. " " .. action)
end

local S = {
	__au_fns = {},
}

function S.exec(id)
	local f = S.__au_fns[id]
	if f["a"] then
		f["f"](unpack(f["a"]))
	else
		f["f"]()
	end
end

function S.set(fn, args)
	local id = string.format("%p", fn)
	S.__au_fns[id] = { f = fn, a = args }

	return string.format('lua as.au.exec("%s")', id)
end

function S.group(grp, cmds)
	cmd("augroup " .. grp)
	cmd("autocmd!")
	if type(cmds) == "function" then
		cmds(as.au)
	else
		for _, au in ipairs(cmds) do
			autocmd(S, au[1], { au[2], au[3] })
		end
	end
	cmd("augroup END")
end

as.au = setmetatable({}, {
	__index = S,
	__newindex = autocmd,
	__call = autocmd,
})

-- lsp
--
-- function as.is_lsp_autostart(server)
-- 	local blacklist = vim.g.self_lsp_autostart_blacklist
-- 	if blacklist == nil or #blacklist < 1 then
-- 		return true
-- 	end
-- 	for _, v in pairs(blacklist) do
-- 		if server == v then
-- 			return false
-- 		end
-- 	end
-- 	return true
-- end

-- default option
function as._default_bool(val, default)
	if val == true or val == nil and default == nil then
		return true
	elseif val == false and default == nil then
		return false
	end
	return default
end

function as._default_num(val, default)
	if val == nil or not tonumber(val) or val <= 0 then
		return default
	end
	return val
end

function as._if_nil(val, default)
	if val == nil then
		return default
	end
	return val
end

-- pretty print wrapper for lua tables
--
-- function as.pprint(...)
-- 	local objects = vim.tbl_map(vim.inspect, { ... })
-- 	print(table.unpack(objects))
-- end

-- treesitter
--
-- function as.node_at_cursor()
-- 	local line, col = table.unpack(vim.api.nvim_win_get_cursor(0))
-- 	return vim.treesitter.get_parser():parse()[1]:root():descendant_for_range(line - 1, col, line - 1, col + 1)
-- end

-- function as.parent_childs()
--   for node, field in as.node_at_cursor():parent():iter_children() do
--     print(node:type())
--   end
-- end

-- lazy require function
--
function as.lazy_require(module)
	local mt = {}

	mt.__index = function(_, key)
		if not mt._module then
			mt._module = require(module)
		end

		return mt._module[key]
	end

	mt.__newindex = function(_, key, val)
		if not mt._module then
			mt._module = require(module)
		end

		mt._module[key] = val
	end

	mt.__metatable = false

	return setmetatable({}, mt)
end
