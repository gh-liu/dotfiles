local M = {}

function M.lint()
	local winnr = vim.fn.win_getid()
	local bufnr = vim.api.nvim_win_get_buf(winnr)

	vim.api.nvim_buf_set_option(
		bufnr,
		"makeprg",
		"golangci-lint run --print-issued-lines=false --exclude-use-default=false"
	)

	vim.api.nvim_buf_set_option(bufnr, "errorformat", "%f:%l:%c: %m")

	vim.cmd(":AsynMake")
end
return M
