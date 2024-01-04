local api = vim.api

local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

-- local require_path = "liu.utils.term"

local g = augroup("liu/term", {})

---@class Term
---@field chan_id integer
local Term = {
	chan_id = 0,
	bufnr = 0,
	name = "",
}

---@class Term[]
local Terms = {}

---Create a new terminal object
---@param args? {enter?:boolean,dir?:string,cmd?:string}
function Term:open(args)
	local args = args or {}
	local enter = args.enter or false
	local dir = args.dir or vim.fn.getcwd()
	local cmd = args.cmd

	local t = {}
	setmetatable(t, self)
	self.__index = self

	local win_old = api.nvim_get_current_win()

	vim.cmd("bo 10new")
	vim.cmd.lcd(dir)
	vim.cmd("terminal")

	local buf = api.nvim_get_current_buf()
	vim.bo[buf].filetype = "term"
	vim.b[buf].term_created_by_liu = true
	vim.keymap.set("n", "q", "<cmd>bd!<cr>", { buffer = buf })

	t.bufnr = buf
	t.chan_id = vim.bo.channel
	t.name = api.nvim_buf_get_name(buf)

	table.insert(Terms, t)

	autocmd({ "BufHidden" }, {
		group = g,
		callback = function(event)
			-- vim.print(event)
		end,
		buffer = buf,
	})

	autocmd({ "BufEnter" }, {
		group = g,
		callback = function(event)
			-- vim.print(event)
		end,
		buffer = buf,
	})

	autocmd({ "BufWipeout" }, {
		group = g,
		callback = function(event)
			for idx, val in ipairs(Terms) do
				if val.bufnr == buf then
					table.remove(Terms, idx)
				end
			end
		end,
		buffer = buf,
	})

	if enter then
		vim.cmd.startinsert()
	else
		api.nvim_set_current_win(win_old)
	end

	return t
end

function Term:exec(cmd)
	api.nvim_chan_send(self.chan_id, cmd .. "\r")

	-- jump to the last line
	api.nvim_buf_call(self.bufnr, function()
		vim.cmd("normal G")
	end)
end

---@return Term[]|nil
function Term.list()
	return #Terms > 0 and Terms or nil
end

return Term
