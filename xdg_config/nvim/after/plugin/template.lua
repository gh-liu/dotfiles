local config_dir = vim.fn.stdpath("config")
local template_dir = config_dir .. "/templates"

--- apply template
---@param buf integer
_G.apply_template = function(buf)
	local filetype = vim.bo.filetype
	local file = vim.fn.bufname(buf)
	local fname = vim.fn.fnamemodify(file, ":t")
	local ext = vim.fn.fnamemodify(file, ":e")
	if #ext > 0 then
		ext = "." .. ext
	end
	-- `.tpl` files are read as is into the buffer,
	-- `.stpl` files treated as snippet which expand via vim.snippet.expand.
	local candidates = {
		fname .. ".tpl" .. ext,
		filetype .. ".tpl",
	}
	for _, candidate in ipairs(candidates) do
		local tmpl = vim.fs.joinpath(template_dir, candidate)
		if vim.uv.fs_stat(tmpl) then
			vim.cmd("0r " .. tmpl)
			return
		end
	end
	local snippet_candidates = {
		fname .. ".stpl" .. ext,
		filetype .. ".stpl",
	}
	for _, candidate in ipairs(snippet_candidates) do
		local tmpl = vim.fs.joinpath(template_dir, candidate)
		local f = io.open(tmpl, "r")
		if f then
			local content = f:read("*a")
			vim.snippet.expand(content)
			f:close()
			return
		end
	end
end
