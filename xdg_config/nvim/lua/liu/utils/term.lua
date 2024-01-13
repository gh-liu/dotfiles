-- local require_path = "liu.utils.term"

local fn = vim.fn
local api = vim.api

local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup
local create_command = api.nvim_create_user_command
local del_command = api.nvim_del_user_command

---@class Term
---@field chan integer
---@field win integer
---@field bufnr integer
---@field name string
local Term = {
	chan = 0,
	win = 0,
	bufnr = 0,
	name = "",
}

Term._instances = {} ---@type Term[]

local global_idx = 0

local g = augroup("liu/term", { clear = true })

---Create a new terminal object
---@return Term
function Term.new()
	local self = setmetatable({}, { __index = Term })
	global_idx = global_idx + 1
	self.name = tostring(global_idx)
	Term._instances[self.name] = self
	return self
end

---@return integer
local new_win = function()
	vim.cmd.new({ mods = { split = "botright" }, range = { 10 } })
	local win_id = api.nvim_get_current_win()
	vim.wo[win_id].winfixheight = true
	return win_id
end

---@param opts? {enter?:boolean,dir?:string,delete_when_close_win?:boolean}
---@return Term
function Term:open(opts)
	local opts = opts or {}
	local enter = opts.enter or false
	local delete_when_close_win = opts.delete_when_close_win or false
	local dir = opts.dir

	local win_old = api.nvim_get_current_win()
	self.win = new_win()
	if delete_when_close_win then
		autocmd("WinClosed", {
			group = g,
			pattern = tostring(self.win),
			callback = function(ev)
				self:clear()
			end,
		})
	end

	if dir then
		vim.cmd.lcd(dir)
	end

	self.chan = fn.termopen({ vim.o.shell })
	self.bufnr = api.nvim_get_current_buf()
	vim.bo[self.bufnr].filetype = "term"

	if not enter then
		api.nvim_set_current_win(win_old)
	end

	return self
end

function Term:exec(cmd)
	api.nvim_chan_send(self.chan, cmd .. "\r")

	-- jump to the last line
	api.nvim_buf_call(self.bufnr, function()
		vim.cmd("normal G")
	end)
end

function Term:clear()
	if api.nvim_win_is_valid(self.win) then
		api.nvim_win_close(self.win, true)
	end
	if api.nvim_buf_is_valid(self.bufnr) then
		api.nvim_buf_delete(self.bufnr, { force = true })
	end
	fn.chanclose(self.chan)

	Term._instances[self.name] = nil
end

function Term.focus(self)
	if api.nvim_win_is_valid(self.win) then
		api.nvim_set_current_win(self.win)
	end
end

local setup_cmd = function()
	---@param name string
	local function create_commands_by_name(name)
		local term = Term._instances[name]

		local execute_command = "TExec" .. name
		create_command(execute_command, function(opt)
			if #opt.args > 0 then
				term:exec(opt.args)
			end

			if not api.nvim_win_is_valid(term.win) then
				local win_old = api.nvim_get_current_win()

				term.win = new_win()
				api.nvim_win_set_buf(term.win, term.bufnr)

				if not opt.bang then
					api.nvim_set_current_win(win_old)
				end
			end

			if opt.bang then
				term:focus()
			end
		end, {
			desc = "Terminal execute command",
			bang = true,
			nargs = "*",
		})

		local delete_command = "TDel" .. name
		create_command(delete_command, function(opt)
			term:clear()
			del_command(execute_command)
			del_command(delete_command)
		end, {
			desc = "Delete terminal",
		})
	end

	create_command("T", function(opt)
		local term = Term.new()
		term:open({ enter = opt.bang })
		term:exec(opt.args)

		create_commands_by_name(term.name)
	end, {
		desc = "Open a new terminal",
		bang = true,
		nargs = "*",
	})
end

return {
	Term = Term,
	setup_cmd = setup_cmd,
}
