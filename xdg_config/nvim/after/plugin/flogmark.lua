local api = vim.api

api.nvim_set_hl(0, "FlogMarkSign", { link = "MarkSign", default = true })

local M = {}

M.ns = api.nvim_create_namespace("liu/flogmark")

api.nvim_create_autocmd("FileType", {
	group = api.nvim_create_augroup("liu/flogmark", { clear = true }),
	pattern = "floggraph",
	callback = function()
		vim.wo.foldcolumn = "1"
		vim.wo.signcolumn = "yes:1"
	end,
})

local function get_flog_state(bufnr)
	if vim.bo[bufnr].filetype ~= "floggraph" then
		return nil
	end

	local state = vim.b[bufnr].flog_state
	if type(state) ~= "table" then
		return nil
	end

	if
		type(state.commits) ~= "table"
		or type(state.commits_by_hash) ~= "table"
		or type(state.commit_marks) ~= "table"
	then
		return nil
	end

	return state
end

local function get_commit_for_mark(state, mark)
	local hash = type(mark) == "table" and mark.hash or nil
	if hash == nil or hash == "" then
		return nil
	end

	local commit_index = state.commits_by_hash[hash]
	if type(commit_index) ~= "number" then
		return nil
	end

	return state.commits[commit_index + 1]
end

local function get_mark_priority(mark_key)
	local char = mark_key:sub(1, 1)
	return vim.hl.priorities.user + string.byte(char)
end

local function get_visible_marks(state, toprow, botrow)
	return vim.iter(state.commit_marks)
		:filter(function(mark_key)
			return mark_key ~= ""
		end)
		:map(function(mark_key, mark)
			local commit = get_commit_for_mark(state, mark)
			local line = commit and commit.line
			if type(line) ~= "number" then
				return nil
			end

			local row = line - 1
			if row < toprow or row >= botrow then
				return nil
			end

			return {
				row = row,
				opts = {
					sign_text = mark_key,
					sign_hl_group = "FlogMarkSign",
					priority = get_mark_priority(mark_key),
				},
			}
		end)
		:filter(function(mark)
			return mark ~= nil
		end)
		:totable()
end

local function clear_marks(bufnr, toprow, botrow)
	api.nvim_buf_clear_namespace(bufnr, M.ns, toprow, botrow)
end

local function render_marks(bufnr, marks)
	for _, mark in ipairs(marks) do
		pcall(api.nvim_buf_set_extmark, bufnr, M.ns, mark.row, 0, mark.opts)
	end
end

function M.collect_marks(bufnr, toprow, botrow)
	local state = get_flog_state(bufnr)
	if not state then
		return {}
	end

	return get_visible_marks(state, toprow, botrow)
end

function M.render(bufnr, toprow, botrow)
	local state = get_flog_state(bufnr)
	clear_marks(bufnr, toprow, botrow)
	if not state then
		return
	end

	local marks = get_visible_marks(state, toprow, botrow)
	render_marks(bufnr, marks)
end

api.nvim_set_decoration_provider(M.ns, {
	on_win = function(_, _, bufnr, toprow, botrow)
		M.render(bufnr, toprow, botrow)
	end,
})
