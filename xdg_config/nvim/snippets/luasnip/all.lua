local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local isn = ls.indent_snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local events = require("luasnip.util.events")
local ai = require("luasnip.nodes.absolute_indexer")
local extras = require("luasnip.extras")
local l = extras.lambda
local rep = extras.rep
local p = extras.partial
local m = extras.match
local n = extras.nonempty
local dl = extras.dynamic_lambda
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local conds = require("luasnip.extras.expand_conditions")
local postfix = require("luasnip.extras.postfix").postfix
local types = require("luasnip.util.types")
local parse = require("luasnip.util.parser").parse_snippet
local ms = ls.multi_snippet
local k = require("luasnip.nodes.key_indexer").new_key

-- todo-comments {{{1
local username = vim.fn.system("git config --get user.name"):gsub("[\n\r]", "")
local email = vim.fn.system("git config --get user.email"):gsub("[\n\r]", "")

local get_date = function()
	return os.date("%d-%m-%y")
end

--- Get the comment string {beg, end} table
---@return table comment_strings {begcstring, endcstring}
local get_comment_string = function()
	local unwrap_cstr = function(cstr)
		local left, right = string.match(cstr, "(.*)%%s(.*)")
		assert(
			(left or right),
			{ msg = string.format("Invalid commentstring for %s! Read `:h commentstring` for help.", vim.bo.filetype) }
		)

		return vim.trim(left), vim.trim(right)
	end
	local cstring = vim.bo.commentstring
	-- as we want only the strings themselves and not strings ready for using `format` we want to split the left and right side
	local left, right = unwrap_cstr(cstring)
	-- create a `{left, right}` table for it
	return { left, right }
end

--- Options for marks to be used in a TODO comment
local marks = {
	-- signature
	function()
		return fmt("<{}>", i(1, username))
	end,
	-- signature_with_email
	function()
		return fmt("<{}{}>", { i(1, username), i(2, " " .. email) })
	end,
	-- date_signature_with_email
	function()
		return fmt("<{}{}{}>", { i(1, get_date()), i(2, ", " .. username), i(3, " " .. email) })
	end,
	-- date_signature
	function()
		return fmt("<{}{}>", { i(1, get_date()), i(2, ", " .. username) })
	end,
	-- date
	function()
		return fmt("<{}>", i(1, get_date()))
	end,
	-- empty
	function()
		return t("")
	end,
}

local generate_todo_comment_snippet_nodes = function(aliases, opts)
	local aliases_nodes = vim.tbl_map(function(alias)
		return i(nil, alias) -- generate choices for [name-of-comment]
	end, aliases)
	local sigmark_nodes = {} -- choices for [comment-mark]
	for _, mark in ipairs(marks) do
		table.insert(sigmark_nodes, mark())
	end

	-- format them into the actual snippet
	local comment_nodes = fmta("<> <>: <> <> <><>", {
		f(function()
			return get_comment_string(opts.comment_type)[1] -- get <comment-string[1]>
		end),
		c(1, aliases_nodes), -- [name-of-comment]
		i(3), -- {comment-text}
		c(2, sigmark_nodes), -- [comment-mark]
		f(function()
			return get_comment_string(opts.comment_type)[2] -- get <comment-string[2]>
		end),
		i(0),
	})
	return comment_nodes
end

--- Generate a TODO comment snippet with an automatic description and docstring
---@param context table merged with the generated context table `trig` must be specified
---@param aliases string[]|string of aliases for the todo comment (ex.: {FIX, ISSUE, FIXIT, BUG})
---@param opts table merged with the snippet opts table
local generate_todo_comment_snippet = function(context, aliases, opts)
	context = context or {}
	if not context.trig then
		return error("context doesn't include a `trig` key which is mandatory", 2) -- all we need from the context is the trigger
	end
	aliases = type(aliases) == "string" and { aliases } or aliases -- if we do not have aliases, be smart about the function parameters
	opts = opts or {}
	local alias_string = table.concat(aliases, "|") -- `choice_node` documentation
	context.name = context.name or (alias_string .. " comment") -- generate the `name` of the snippet if not defined
	context.dscr = context.dscr or (alias_string .. " comment with a signature-mark") -- generate the `dscr` if not defined
	context.docstring = context.docstring or (" {1:" .. alias_string .. "}: {3} <{2:mark}>{0} ") -- generate the `docstring` if not defined
	local comment_nodes = generate_todo_comment_snippet_nodes(aliases, opts) -- nodes from the previously defined function for their generation
	return s(context, comment_nodes, opts) -- the final todo-snippet constructed from our parameters
end

local todo_snippet_specs = {
	{ { trig = "todo" }, "TODO" },
	{ { trig = "fix" }, { "FIX", "BUG", "ISSUE", "FIXIT" } },
	{ { trig = "hack" }, "HACK" },
	{ { trig = "warn" }, { "WARN", "WARNING", "XXX" } },
	{ { trig = "perf" }, { "PERF", "PERFORMANCE", "OPTIM", "OPTIMIZE" } },
	{ { trig = "note" }, { "NOTE", "INFO" } },
}

local todo_comment_snippets = {}
for _, v in ipairs(todo_snippet_specs) do
	table.insert(todo_comment_snippets, generate_todo_comment_snippet(v[1], v[2], v[3]))
end

ls.add_snippets("all", todo_comment_snippets, { type = "snippets", key = "todo_comments" })
-- }}}1

-- vim: set foldmethod=marker foldlevel=1:
