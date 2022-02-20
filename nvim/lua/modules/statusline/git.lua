local M = {}

local signs = {}
signs.Add = " + "
signs.Changed = " ~ "
signs.Removed = " - "
signs.branch = "  "

local function get_info(type)
	local git_info = vim.b.gitsigns_status_dict
	if not git_info or git_info.head == "" then
		return ""
	end
	local nr = ""
	if type == "added" then
		nr = git_info.added and git_info.added or ""
	end
	if type == "removed" then
		nr = git_info.changed and git_info.changed or ""
	end
	if type == "changed" then
		nr = git_info.removed and git_info.removed or ""
	end
	if type == "head" then
		nr = git_info.head and git_info.head or ""
	end
	return nr
end

function M.added()
	return get_info("added"), signs.Add
end

function M.changed()
	return get_info("removed"), signs.Changed
end

function M.removed()
	return get_info("changed"), signs.Removed
end

function M.head()
	return get_info("head"), signs.branch
end

return M
