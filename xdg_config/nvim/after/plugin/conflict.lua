if false then
	return
end

--- @class Range
--- @field range_start integer
--- @field range_end integer
--- @field content_start integer
--- @field content_end integer

--- @class Marker
--- @field label integer
--- @field content string

--- @class Markers
--- @field current Marker
--- @field incoming Marker
--- @field ancestor Marker

--- @class Conflict
--- @field incoming Range
--- @field middle Range
--- @field current Range
--- @field marks Markers

local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

--[[
<<<<<<<<< Temporary merge branch 1
<snip>
||||||||| merged common ancestors
=========
<snip>
>>>>>>>>> Temporary merge branch 2
]]

local marker = {
	start = "^<\\{7} ",
	separator = "^=\\{7}",
	ancestor = "^|\\{7} ",
	end1 = "^>\\{7} ",
}

local function find_conflict()
	local s = vim.fn.search(marker.start, "cW")
	local sep = vim.fn.search(marker.separator, "cW")
	local e = vim.fn.search(marker.end1, "cW")
	if s == 0 or sep == 0 or e == 0 then
		return nil
	end
	return { s, sep, e }
end

local function has_conflict()
	local has = true
	local view = vim.fn.winsaveview()
	vim.cmd([[keepjumps call cursor(1, 1)]])
	local conflict = find_conflict()
	if not conflict then
		has = false
	end
	vim.fn.winrestview(view)
	return has
end

local function on_conflict(bufnr)
	vim.notify("[Git] Conflict detected!", vim.log.levels.WARN)
end

autocmd("BufReadPost", {
	group = augroup("liu_git_conflict", {}),
	callback = function(ev)
		if has_conflict() then
			on_conflict(ev.buf)
		end
	end,
	desc = "Git Conflict",
})
