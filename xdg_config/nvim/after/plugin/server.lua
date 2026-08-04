local uv = vim.uv
local server = vim.v.servername
local link = "/tmp/nvim.sock"

if server ~= "" and server ~= link then
	local temporary = string.format("%s.%d", link, uv.os_getpid())

	uv.fs_unlink(temporary)
	if uv.fs_symlink(server, temporary) and not uv.fs_rename(temporary, link) then
		uv.fs_unlink(temporary)
	end
end

vim.schedule(function()
	vim.cmd("silent! detach!")
end)
