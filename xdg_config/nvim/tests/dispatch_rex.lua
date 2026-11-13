-- Run inside Rex: nvim --clean -l xdg_config/nvim/tests/dispatch_rex.lua
-- Requires vim-dispatch installed in Neovim's standard package directory.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)
vim.opt.packpath:prepend(vim.fn.stdpath("data") .. "/site")
vim.cmd.packadd("vim-dispatch")
vim.cmd.runtime("plugin/dispatch.vim")
vim.g.dispatch_handlers = { "rex", "job", "terminal" }
vim.o.shell = "/bin/sh"
vim.o.makeprg = "env"
vim.o.errorformat = "%f:%l:%c:%m"

assert(vim.env.REX_BLOCK and vim.fn.executable("rex") == 1, "Run this test inside Rex")
local anchor = vim.env.REX_BLOCK
local directory = vim.fn.tempname() .. " space's"
vim.fn.mkdir(directory, "p")
directory = assert(vim.uv.fs_realpath(directory))
local blocks = {}
local function rex(args)
	local result = vim.system(vim.list_extend({ "rex", "--autostart=false" }, args), { text = true }):wait()
	assert(result.code == 0, result.stderr)
	return result.stdout
end
local function focused_block()
	local view = vim.json.decode(rex({ "window", "ls", "--json" }))
	for _, window in ipairs(view.windows) do
		if window.window_id == view.active_window_id then
			return window.focused_block_id
		end
	end
end
local function wait_for(predicate)
	assert(vim.wait(10000, predicate, 20), "Timed out waiting for dispatch")
end
local function request()
	local value = vim.fn["dispatch#request"]()
	assert(value.handler == "rex", vim.inspect(value))
	blocks[#blocks + 1] = value.rex_block
	return value
end
local function complete(value)
	wait_for(function()
		return vim.fn["dispatch#completed"](value.id) == 1
	end)
	return vim.fn.readfile(value.file .. ".complete")[1]
end

local ok, err = xpcall(function()
	rex({ "focus", anchor })
	vim.cmd.cd(vim.fn.fnameescape(directory))
	vim.env.DISPATCH_REX_TEST = "quoted ' value $HOME"
	local command = "printf 'sample.c:7:3:%s\\n' \"$DISPATCH_REX_TEST\"; "
		.. "printf 'sample.c:9:2:stderr\\n' >&2; pwd; printf '%s\\n' \"$REX_BLOCK\"; sh -c 'exit 7'"
	vim.cmd("Dispatch -- " .. command)
	local failed = request()
	assert(focused_block() == anchor, "Dispatch must preserve editor focus")
	assert(complete(failed) == "7")
	local output = vim.fn.readfile(failed.file)
	assert(vim.tbl_contains(output, directory), vim.inspect(output))
	assert(vim.tbl_contains(output, failed.rex_block), "Child must receive its own Rex block ID")
	local errors = vim.tbl_filter(function(item)
		return item.valid == 1
	end, vim.fn.getqflist())
	assert(#errors == 2, vim.inspect(errors))
	assert(errors[1].lnum == 7 and errors[1].col == 3 and errors[1].text == vim.env.DISPATCH_REX_TEST)
	assert(errors[2].lnum == 9 and errors[2].text == "stderr")

	vim.cmd("Dispatch! -- printf 'success\\n'")
	assert(complete(request()) == "0")
	vim.g.dispatch_fifo_callback = 0
	vim.cmd("Dispatch! -- printf 'without callback\\n'; sh -c 'exit 4'")
	assert(complete(request()) == "4")
	vim.g.dispatch_fifo_callback = 1

	vim.cmd("Dispatch! -- sleep 5")
	local aborted = request()
	local pid = vim.fn["dispatch#pid"](aborted)
	vim.cmd.AbortDispatch()
	assert(vim.fn["dispatch#request"]().aborted == 1)
	wait_for(function()
		return vim.uv.kill(pid, 0) == nil
	end)

	vim.cmd("Start! -wait=always printf 'interactive\\n'")
	local started = vim.g.dispatch_last_start
	assert(started.handler == "rex")
	blocks[#blocks + 1] = started.rex_block
	assert(focused_block() == anchor, "Start! must preserve editor focus")
	wait_for(function()
		return rex({ "capture", "-b", started.rex_block, "--trim" }):find("Press ENTER", 1, true) ~= nil
	end)
	vim.cmd("Start -wait=always printf 'interactive\\n'")
	assert(focused_block() == started.rex_block, "Start must reactivate the existing pane")
	rex({ "send", "-b", started.rex_block, "\n" })
	wait_for(function()
		return vim.fn.filereadable(started.file .. ".complete") == 1
	end)

	vim.env.REX_BLOCK = nil
	vim.cmd("Dispatch! -- printf 'fallback\\n'")
	local fallback = vim.fn["dispatch#request"]()
	assert(fallback.handler == "job")
	assert(complete(fallback) == "0")
end, debug.traceback)

vim.env.REX_BLOCK = anchor
for _, block in ipairs(blocks) do
	vim.system({ "rex", "--autostart=false", "block", "close", block }):wait()
end
rex({ "focus", anchor })
vim.fn.delete(directory, "rf")
if not ok then
	error(err)
end
print("Rex dispatch integration tests passed")
