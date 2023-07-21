_G.config = {
	borders = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
	-- fold_markers = { "►", "" },
	fold_markers = { "", "" },
	icons = { Error = "E", Warn = "W", Info = "I", Hint = "H" },
	-- icons = {
	-- 	Error = "",
	-- 	Warn = "",
	-- 	Info = "",
	-- 	Hint = "",
	-- },
	debug_icons = {
		-- bug = "",
		bug = "$",
	},
	colors = {
		gray = "#616E88",
		green = "#A3BE8C",
		blue = "#5E81AC",
		cyan = "#88C0D0",
		red = "#BF616A",
		orange = "#D08770",
		yellow = "#EBCB8B",
		magenta = "#B48EAD",
		line = "#3B4252", -- same as gray
	},
	kind_icons = {
		Text = "",
		Method = "",
		Function = "",
		Constructor = "",
		Field = "",
		Variable = "",
		Class = "",
		Interface = "",
		Module = "",
		Property = "",
		Unit = "",
		Value = "",
		Enum = "",
		Keyword = "",
		Snippet = "",
		Color = "",
		File = "",
		Reference = "",
		Folder = "",
		EnumMember = "",
		Constant = "",
		Struct = "",
		Event = "",
		Operator = "",
		TypeParameter = "",
	},
}

_G.set_hls = function(highlights)
	local nvim_set_hl = vim.api.nvim_set_hl
	for group, opts in pairs(highlights) do
		nvim_set_hl(0, group, opts)
	end
end

---@param alias table
_G.set_alias = function(alias)
	for key, value in pairs(alias) do
		vim.api.nvim_create_user_command(key, function()
			vim.cmd(value)
		end, {})
	end
end

local stack = {}
local global_keymaps = {}
_G.stack_map = {
	set = function(name, maps)
		for _, map in ipairs(maps) do
			local mode = map[1]
			local lhs = map[2]
			local rhs = map[3]
			local opts = vim.deepcopy(map[4] or {})

			vim.validate({
				map = { map, "t" },
				mode = { mode, "s" },
				lhs = { lhs, "s" },
				rhs = { rhs, { "s", "f" } },
				opts = { opts, "t", true },
			})

			if not stack[name] then
				stack[name] = {}
			end
			if not stack[name][mode] then
				stack[name][mode] = {}
			end

			local keymaps = global_keymaps[mode]
			if not keymaps then
				keymaps = vim.api.nvim_get_keymap(mode)
				global_keymaps[mode] = keymaps
			end

			local old_map = vim.tbl_filter(function(v)
				return v.lhs == string.gsub(lhs, "<leader>", vim.g.mapleader or " ")
			end, keymaps)[1] or true

			stack[name][mode][lhs] = old_map

			vim.keymap.set(mode, lhs, rhs, opts)
		end
	end,
	del = function(name)
		if not stack[name] then
			return
		end

		for mode, maps in pairs(stack[name]) do
			for lhs, m in pairs(maps) do
				if type(m) == "boolean" then
					vim.keymap.del(mode, lhs)
				else
					local lhs = m.lhs
					local rhs = m.callback or m.rhs
					local opts = {
						noremap = m.noremap,
						silent = m.silent,
						script = m.script,
						nowait = m.nowait,
						unique = m.unique,
						desc = m.desc,
					}
					vim.keymap.set(mode, lhs, rhs, opts)
				end
			end
		end

		stack[name] = nil
	end,
}
