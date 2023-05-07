if true then
	return
end

-- gitsign {{{
set_hls({
	ColumnAdd = { fg = config.colors.green },
	ColumnChange = { fg = config.colors.yellow },
	ColumnDelete = { fg = config.colors.red },
})

local git_signs = {
	add = "ColumnAdd",
	change = "ColumnChange",
	delete = "ColumnDelete",
}

local gitsigns_bar = "│"
local stc_gitsign_lines_var_name = "stc_gitsign_lines"

_G.get_statuscol_gitsign = function(bufnr, lnum)
	local lines = vim.b[stc_gitsign_lines_var_name]

	if not lines then
		return " "
	end
	local line = tostring(lnum)
	local t = lines[line]
	if not t then
		return " "
	end
	return table.concat({ "%#", git_signs[t], "#", gitsigns_bar, "%*" })
end

local update_sign_info = function (bufnr)
	local gs = require("gitsigns")
	local hunks = gs.get_hunks(bufnr)
	local lines = {}
	if hunks then
		-- Array of hunk objects. Each hunk object has keys:
		--   • `"type"`: String with possible values: "add", "change",
		--     "delete"
		--   • `"head"`: Header that appears in the unified diff
		--     output.
		--   • `"lines"`: Line contents of the hunks prefixed with
		--     either `"-"` or `"+"`.
		--   • `"removed"`: Sub-table with fields:
		--     • `"start"`: Line number (1-based)
		--     • `"count"`: Line count
		--   • `"added"`: Sub-table with fields:
		--     • `"start"`: Line number (1-based)
		--     • `"count"`: Line count
		-- local bufnr = vim.api.nvim_get_current_buf()
		for _, h in ipairs(hunks) do
			if h.type == "add" then
				local line = h.added.start - 1
				for i = 1, h.added.count, 1 do
					line = line + 1
					line = tostring(line)
					lines[line] = h.type
				end
				goto continue
			end
			if h.type == "change" then
				local line = h.added.start - 1
				local added_count = h.added.count - h.removed.count
				if added_count >= 0 then
					for i = 1, h.removed.count, 1 do
						line = line + 1
						line = tostring(line)
						lines[line] = h.type
					end

					for i = 1, added_count, 1 do
						line = line + 1
						line = tostring(line)
						lines[line] = "add"
					end
				else
					for i = 1, h.added.count, 1 do
						line = line + 1
						line = tostring(line)
						lines[line] = h.type
					end
				end
				goto continue
			end
			if h.type == "delete" then
				local line = h.added.start
				line = tostring(line)
				lines[line] = h.type
				goto continue
			end

			::continue::
		end
	end

	vim.b[stc_gitsign_lines_var_name] = lines
end

vim.api.nvim_create_autocmd("BufEnter", {
	callback = function(opt)
		update_sign_info(opt.bufnr)
		-- vim.cmd([[redrawstatus]])
	end
})
vim.api.nvim_create_autocmd("User", {
	pattern = { "GitSignsUpdate" },
	callback = function(opt)
		update_sign_info(opt.bufnr)
		-- vim.cmd([[redrawstatus]])
	end,
})

-- }}}

_G.get_statuscol = function()
	local stc_strs = {}

	-- signcol
	table.insert(stc_strs, "%s")
	-- sep
	table.insert(stc_strs, "%=")
	-- num https://github.com/neovim/neovim/issues/21745
	table.insert(
		stc_strs,
		[[%{%v:virtnum?'':(&nu?(&rnu?(v:relnum?v:relnum:printf('%-'.max([3,len(line('$'))]).'S',v:lnum)):v:lnum):(&rnu?v:relnum:''))%}]]
	)
	-- gitsign
	table.insert(stc_strs, "%{%v:lua.get_statuscol_gitsign(bufnr(), v:lnum)%}")
	-- space
	table.insert(stc_strs, " ")

	return table.concat(stc_strs, "")
end

vim.o.statuscolumn = "%!v:lua.get_statuscol()"

-- vim: set foldmethod=marker foldlevel=1:
