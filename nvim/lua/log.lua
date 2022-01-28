local M = {}

local vimm = vim

M.DEBUG = function(msg)
	vimm.notify(msg, vimm.lsp.log_levels.DEBUG)
end

M.INFO = function(msg)
	vimm.notify(msg, vimm.lsp.log_levels.INFO)
end

M.WARN = function(msg)
	vimm.notify(msg, vimm.lsp.log_levels.WARN)
end

M.ERROR = function(msg)
	vimm.notify(msg, vimm.lsp.log_levels.ERROR)
end

return M
