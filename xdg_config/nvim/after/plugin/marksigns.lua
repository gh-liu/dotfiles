vim.api.nvim_set_hl(0, "MarkSign", { link = "SpecialChar", default = true })

vim.keymap.set("n", "dm", "<Cmd>exe 'delmarks ' . getcharstr()<CR>", { desc = "Del mark" })

local ns_marksigns = vim.api.nvim_create_namespace("liu.marksigns")

--- @param bufnr integer
--- @param name string single char like "a" or "A"
local function render_mark(bufnr, name)
	if not vim.api.nvim_buf_is_loaded(bufnr) or vim.bo[bufnr].buftype == "terminal" then
		return
	end
	local id = string.byte(name)
	local row
	if name:match("%u") then
		local m = vim.api.nvim_get_mark(name, {})
		local bufname = vim.api.nvim_buf_get_name(bufnr)
		if m[3] == bufnr or (m[4] ~= "" and vim.fn.fnamemodify(m[4], ":p:a") == bufname) then
			row = m[1]
		end
	else
		row = vim.api.nvim_buf_get_mark(bufnr, name)[1]
	end
	if row and row > 0 and row <= vim.api.nvim_buf_line_count(bufnr) then
		local nr = vim.fn.str2nr(name)
		local priority = vim.hl.priorities.user + (name:match("%l") and nr - 32 or nr)
		pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_marksigns, row - 1, 0, {
			id = id,
			sign_text = "'" .. name,
			sign_hl_group = "MarkSign",
			priority = priority,
		})
	else
		vim.api.nvim_buf_del_extmark(bufnr, ns_marksigns, id)
	end
end

local aug_marksigns = vim.api.nvim_create_augroup("liu.marksigns", { clear = true })
vim.api.nvim_create_autocmd("BufRead", {
	group = aug_marksigns,
	desc = "Draw mark signs on buffer read",
	callback = function(e)
		vim.api.nvim_buf_clear_namespace(e.buf, ns_marksigns, 0, -1)
		local bufname = vim.api.nvim_buf_get_name(e.buf)
		-- Global marks (uppercase) belonging to this file
		for _, m in ipairs(vim.fn.getmarklist()) do
			local name = m.mark:sub(2)
			if name:match("^%u$") and vim.fn.fnamemodify(m.file, ":p:a") == bufname then
				render_mark(e.buf, name)
			end
		end
		-- Local marks (lowercase)
		for _, m in ipairs(vim.fn.getmarklist(e.buf)) do
			local name = m.mark:sub(2)
			if name:match("^%l$") then
				render_mark(e.buf, name)
			end
		end
	end,
})
vim.api.nvim_create_autocmd("MarkSet", {
	group = aug_marksigns,
	pattern = "[A-Za-z]",
	desc = "Draw mark sign when mark is set",
	callback = function(e)
		-- For global marks, redraw across all loaded buffers
		if e.match:match("%u") then
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				render_mark(buf, e.match)
			end
		else
			render_mark(e.buf, e.match)
		end
	end,
})
