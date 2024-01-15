if true then
	return
end

local fn = vim.fn
local api = vim.api
local lsp = vim.lsp
local ms = lsp.protocol.Methods

local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local fold_method = ms.textDocument_foldingRange

local M = {
	foldlevels = {},
}

--- Returns the fold level for a line in a buffer.
---
---@param bufnr integer bufnr
---@param linenr integer line number
---@return integer fold level
function M.get_fold_level(bufnr, linenr)
	if not M.foldlevels[bufnr] then
		return 0
	end
	return M.foldlevels[bufnr][linenr]
end

--- Returns the fold level for a line in the current buffer.
---
--- Can be used as 'foldexpr', see |fold-expr|.
---@param lnum integer line number, see |v:lnum|
---@return integer fold level
function M.foldexpr(lnum)
	local bufnr = api.nvim_get_current_buf()
	return M.get_fold_level(bufnr, lnum)
end

_G.nvim_lsp_fold_expr = M.foldexpr

function M.set_fold_options(winid)
	local opts = {
		foldmethod = "expr",
		foldexpr = "luaeval('nvim_lsp_foldexpr('..v:lnum..')')",
		foldlevel = 9,
	}
	for opt, value in pairs(opts) do
		api.nvim_set_option_value(opt, value, { scope = "local", win = winid })
	end
end

--- Creates |folds| for the current buffer.
---
--- This will also set 'foldmethod' and "foldexpr".
---
--- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_foldingRange
function M.update_document_fold()
	lsp.buf_request(
		0,
		fold_method,
		{ textDocument = lsp.util.make_text_document_params() },
		function(err, result, context, config)
			if err then
				vim.notify(err.message, vim.log.levels.ERROR)
				return
			end
			if not result then
				return
			end

			local endlevels = {}
			---@type integer
			local bufnr = context.bufnr
			M.foldlevels[bufnr] = {}

			---@type lsp.FoldingRange[]
			local ranges = result
			vim.print(ranges)
			for _, range in ipairs(ranges) do
				if range.startLine ~= range.endLine then
					for linenr = range.startLine + 1, range.endLine + 1 do
						M.foldlevels[bufnr][linenr] = (M.foldlevels[bufnr][linenr] or 0) + 1
					end
					-- Need to make sure to mark the last line in the range
					-- with the lowest fold level ending on that line
					local _el = endlevels[range.endLine + 1] or math.huge
					local el_ = M.foldlevels[bufnr][range.endLine + 1]
					endlevels[range.endLine + 1] = math.min(_el, el_)
				end
			end

			for linenr, level in pairs(endlevels) do
				M.foldlevels[bufnr][linenr] = "<" .. level
			end

			-- Force refresh by setting folding options
			for _, winid in ipairs(fn.win_findbuf(bufnr)) do
				M.set_fold_options(winid)
			end
		end
	)
end

local aug = augroup("liu/lsp_folding", { clear = true })

autocmd("LspAttach", {
	group = aug,
	callback = function(args)
		local bufnr = args.buf
		local client = lsp.get_client_by_id(args.data.client_id)
		if client.supports_method(fold_method) then
			M.update_document_fold()
			autocmd({ "InsertLeave", "TextChanged" }, {
				buffer = bufnr,
				callback = M.update_document_fold,
			})
		end
	end,
})
