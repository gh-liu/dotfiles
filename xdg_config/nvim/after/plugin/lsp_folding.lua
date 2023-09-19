if true then
	return
end

local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local method = "textDocument/foldingRange"

local user_lsp_attach_folding = augroup("UserLspAttachFolding", { clear = true })

autocmd("LspAttach", {
	group = user_lsp_attach_folding,
	callback = function(args)
		local bufnr = args.buf

		local client = vim.lsp.get_client_by_id(args.data.client_id)
		-- if client.server_capabilities.foldingRangeProvider then
		if client.supports_method(method) then
			local cur_win = api.nvim_get_current_win()
			local win_foldexpr = api.nvim_win_get_option(cur_win, "foldmethod")
			if win_foldexpr == "marker" then
				return
			end

			update_lsp_foldexpr()

			autocmd({ "InsertLeave", "TextChanged" }, {
				buffer = bufnr,
				callback = update_lsp_foldexpr,
			})
		end
	end,
})

local foldlevels = {}

--- Applies a list of fold ranges to a certain buffer.
---
--@param bufnr buffer id
--@param ranges list of `FoldingRange` objects
local function update_folds(bufnr, ranges)
	foldlevels[bufnr] = {}
	local endlevels = {}
	for _, range in ipairs(ranges) do
		if range.startLine ~= range.endLine then
			for linenr = range.startLine + 1, range.endLine + 1 do
				foldlevels[bufnr][linenr] = (foldlevels[bufnr][linenr] or 0) + 1
			end
			-- Need to make sure to mark the last line in the range
			-- with the lowest fold level ending on that line
			local _el = endlevels[range.endLine + 1] or math.huge
			local el_ = foldlevels[bufnr][range.endLine + 1]
			endlevels[range.endLine + 1] = math.min(_el, el_)
		end
	end

	for linenr, level in pairs(endlevels) do
		foldlevels[bufnr][linenr] = "<" .. level
	end

	-- Force refresh by setting folding options
	for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
		vim.api.nvim_win_set_option(winid, "foldexpr", "luaeval('lsp_foldexpr('..v:lnum..')')")
		vim.api.nvim_win_set_option(winid, "foldmethod", "expr")
		vim.api.nvim_win_set_option(winid, "foldlevel", 9)
	end
end

--- Returns the fold level for a line in a buffer.
--@param bufnr buffer id
--@param linenr line number (1-indexed)
--@returns fold level
local function get_fold_level(bufnr, linenr)
	if not foldlevels[bufnr] then
		return 0
	end
	return foldlevels[bufnr][linenr]
end

local function handler(_, result, ctx, _)
	if not result then
		return
	end
	update_folds(ctx.bufnr, result)
end

local M = {}

--- Creates |folds| for the current buffer.
---
--- This will also set 'foldmethod' to "expr" and use |vim.lsp.buf.foldexpr()|
--- for 'foldexpr'.
---
--- Note: The folds are not updated automatically after subsequent changes.
--- To update them whenever leaving insert mode, use
---
--- <pre>
--- vim.api.nvim_command[[autocmd InsertLeave <buffer> lua vim.lsp.buf.document_fold()]]
--- </pre>
--@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_foldingRange
function M.document_fold()
	local params = { textDocument = vim.lsp.util.make_text_document_params() }
	vim.lsp.buf_request(0, method, params, handler)
end

_G.update_lsp_foldexpr = M.document_fold

--- Returns the fold level for a line in the current buffer as determined
--- by a server.
---
--- Can be used as 'foldexpr', see |fold-expr|.
---
--- Note: To update the folds it is necessary to call |vim.lsp.buf.document_fold()|.
--@param lnum line number |v:lnum|
--@returns fold level
function M.foldexpr(lnum)
	local bufnr = vim.api.nvim_get_current_buf()
	return get_fold_level(bufnr, lnum)
end

_G.lsp_foldexpr = M.foldexpr

-- local capabilities = vim.lsp.protocol.make_client_capabilities()
-- capabilities.textDocument.foldingRange = {
-- 	dynamicRegistration = false,
-- 	lineFoldingOnly = true,
-- }
