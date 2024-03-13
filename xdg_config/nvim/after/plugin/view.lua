if true then
	return
end
local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

---@type fun(buf: integer): boolean
local enable_view = function(buf)
	return not vim.b.disable_view
		and api.nvim_buf_get_name(buf) ~= ""
		and api.nvim_get_option_value("buftype", { buf = buf }) == ""
end

local view_group = augroup("liu/auto_view", { clear = true })
autocmd({
	"BufWritePre",
	"BufWinLeave",
	"BufDelete",
}, {
	group = view_group,
	callback = function(ev)
		if enable_view(ev.buf) then
			api.nvim_buf_call(ev.buf, function()
				-- vim.cmd([[mkview 9]])
				-- :h nvim_parse_cmd
				vim.cmd({
					cmd = "mkview",
					args = { "9" },
				})
			end)
		end
	end,
	desc = "auto mkview",
})
autocmd({
	"BufReadPost",
	"BufWinEnter",
}, {
	group = view_group,
	callback = function(ev)
		if enable_view(ev.buf) then
			-- vim.cmd([[silent! loadview 9]])
			-- :h nvim_parse_cmd
			vim.schedule(function()
				vim.cmd({
					cmd = "loadview",
					args = { "9" },
					mods = { emsg_silent = true },
				})
			end)
		end
	end,
	nested = true,
	desc = "auto loadview",
})

local function delete_view(file)
	local fn = vim.fn
	---@type string
	local path
	path = fn.fnamemodify(fn.bufname("%"), ":p")
	local home = os.getenv("HOME")
	if home then
		path = path:gsub(home, "~")
	end
	path = path:gsub("/", "=+")
	path = vim.api.nvim_get_option_value("viewdir", {}) .. "/" .. path
	path = path .. "="
	if file and string.match(file, "%d") then
		path = path .. file .. ".vim"
	end
	local b, err = os.remove(path)
	if b then
		vim.notify("Deleted view: " .. path, vim.log.levels.INFO)
	else
		vim.notify(err, vim.log.levels.ERROR)
	end
end

api.nvim_create_user_command("Delview", function(opts)
	local file = #opts.fargs > 0 and opts.fargs[1] or nil
	delete_view(file)

	vim.b.disable_view = true
end, {
	nargs = "?",
})
