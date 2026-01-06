local api = vim.api

local augroup = api.nvim_create_augroup("liu/fugitive/stash", { clear = true })
local stash_list_cmd = "--paginate stash list '--pretty=format:%h %as %<(10)%gd %<(76,trunc)%s'"

-- czl: list, czm: save (in fugitive buffer)
api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = "fugitive",
	callback = function()
		local buf = api.nvim_get_current_buf()
		vim.keymap.set("n", "czl", ":G " .. stash_list_cmd .. "<CR>", { buffer = buf })
		vim.keymap.set("n", "czm", ":G stash save<space>", { buffer = buf, nowait = true })
	end,
})

-- czd: drop, czO: pop, czo: pop --index (in FugitivePager)
api.nvim_create_autocmd("User", {
	group = augroup,
	pattern = "FugitivePager",
	callback = function(data)
		local buf = data.buf
		vim.bo.bufhidden = "delete"

		local refresh = function()
			api.nvim_buf_call(buf, function()
				vim.cmd(":0G " .. stash_list_cmd)
			end)
		end

		local get_stash = function()
			local line = api.nvim_get_current_line()
			local _, _, hash, stash_idx = line:find([[(%x+).*(stash@{%d})]])
			return stash_idx
		end

		local op_stash = function(fn)
			local idx = get_stash()
			if idx then
				fn(idx)
				refresh()
			end
		end

		vim.keymap.set("n", "czd", function()
			op_stash(function(i)
				vim.cmd("Git stash drop --quiet " .. i)
			end)
		end, { buffer = buf })
		vim.keymap.set("n", "czO", function()
			op_stash(function(i)
				vim.cmd("Git stash pop --quiet " .. i)
			end)
		end, { buffer = buf })
		vim.keymap.set("n", "czo", function()
			op_stash(function(i)
				vim.cmd("Git stash pop --quiet --index " .. i)
			end)
		end, { buffer = buf })
	end,
})

-- GStashList command
api.nvim_create_user_command("GStashList", function()
	local cmd = { "git", "stash", "list", "--pretty=format:%H %<(10)%gd %<(76,trunc)%s" }
	local obj = vim.system(cmd, { text = true }):wait()
	local lines = vim.split(obj.stdout, "\n")
	local dir = vim.fn["FugitiveGitDir"]()
	local qfitems = {}
	for _, line in ipairs(lines) do
		local hash, stash_id, message = line:match("^(%x+)%s+(%g+)%s+(.*)$")
		table.insert(qfitems, {
			module = hash,
			filename = string.format("fugitive://%s//%s", dir, hash),
			text = message,
		})
	end
	if #qfitems > 0 then
		vim.fn.setqflist(qfitems)
		vim.cmd.copen()
	end
end, { nargs = 0 })
