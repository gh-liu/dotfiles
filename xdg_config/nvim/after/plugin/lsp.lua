local api = vim.api
local create_command = api.nvim_create_user_command
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local keymap = vim.keymap

local lsp = vim.lsp
local lsp_protocol = lsp.protocol
local ms = lsp_protocol.Methods

---@param group_name string
local lsp_augroup = function(group_name)
	return augroup("liu/lsp_attach_" .. group_name, { clear = true })
end

-- Log Levels {{{2
lsp.set_log_level("OFF")

create_command("LspSetLogLevel", function(opts)
	local level = unpack(opts.fargs)
	lsp.set_log_level(level)
	vim.notify("Set: " .. level, vim.log.levels.INFO)
end, {
	desc = "Set Lsp Log Level",
	nargs = 1,
	complete = function()
		return { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF" }
	end,
})
-- }}}

-- keymaps {{{2
autocmd("LspAttach", {
	group = lsp_augroup("keymaps"),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		local bufnr = args.buf

		-- vim.bo[bufnr].omnifunc = "v:lua.lsp.omnifunc"
		-- vim.bo[bufnr].tagfunc = "v:lua.lsp.tagfunc"
		-- vim.bo[bufnr].formatexpr = "v:lua.lsp.formatexpr(#{timeout_ms:250})"

		local nmap = function(lhs, func, desc)
			if desc then
				desc = "LSP: " .. desc
			end
			keymap.set("n", lhs, func, { buffer = bufnr, desc = desc })
		end

		nmap("gD", lsp.buf.declaration, "[G]oto [D]eclaration")
		-- nmap("gd", lsp.buf.definition, "[G]oto [D]efinition")
		-- nmap("gy", lsp.buf.type_definition, "[G]oto T[y]pe Definition")
		-- nmap("gr", lsp.buf.references, "[G]oto [R]eferences")
		-- nmap("gi", lsp.buf.implementation, "[G]oto [I]mplementation")
		-- nmap("K", lsp.buf.hover, "Hover Documentation")

		if client.supports_method(ms.textDocument_rename) then
			nmap("crn", lsp.buf.rename, "[R]e[n]ame")
		end

		nmap("<leader>cl", lsp.codelens.run, "[C]ode [L]en")
		keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { buffer = bufnr, desc = "[C]ode [A]ction" })

		keymap.set("i", "<C-]>", lsp.buf.signature_help, { buffer = bufnr, desc = "Signature Documentation" })
	end,
})
-- }}}

-- workspace {{{2
autocmd("LspAttach", {
	group = lsp_augroup("workspace"),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		local bufnr = args.buf

		api.nvim_buf_create_user_command(bufnr, "LspWorkspaceFolderAdd", function(opts)
			lsp.buf.add_workspace_folder()
		end, { nargs = 0 })

		api.nvim_buf_create_user_command(bufnr, "LspWorkspaceFolderList", function(opts)
			vim.print(lsp.buf.list_workspace_folders())
		end, { nargs = 0 })

		api.nvim_buf_create_user_command(bufnr, "LspWorkspaceFolderDelete", function(opts)
			lsp.buf.remove_workspace_folder(opts.fargs[1])
		end, {
			nargs = 1,
			complete = function()
				return lsp.buf.list_workspace_folders()
			end,
		})
	end,
})
-- }}}

-- codelens {{{2
autocmd("LspAttach", {
	group = lsp_augroup("codelens"),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		if client and client.supports_method("textDocument/codeLens") then
			local bufnr = args.buf
			autocmd({ "CursorHold", "InsertLeave" }, {
				callback = function(ev)
					lsp.codelens.refresh({ bufnr = ev.buf })
				end,
				buffer = bufnr,
			})
		end
	end,
})
-- }}}

-- inlayhint {{{2
autocmd("LspAttach", {
	group = lsp_augroup("inlayhint"),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		if client.supports_method("textDocument/inlayHint") then
			local bufnr = args.buf
			local inlay_hint = lsp.inlay_hint

			inlay_hint.enable(true, { bufnr = bufnr })

			api.nvim_buf_create_user_command(bufnr, "InlayHintToggle", function(opts)
				inlay_hint.enable(not inlay_hint.is_enabled(bufnr), { bufnr = bufnr })
			end, { nargs = 0 })

			api.nvim_buf_create_user_command(bufnr, "InlayHintRefresh", function(opts)
				inlay_hint.enable(false, { bufnr = bufnr })
				inlay_hint.enable(true, { bufnr = bufnr })
			end, { nargs = 0 })
		end
	end,
})
-- }}}

-- document highlight {{{2
autocmd("LspAttach", {
	group = lsp_augroup("document_highlight"),
	callback = function(args)
		if vim.b.lsp_document_highlight_disable then
			return
		end

		local client = lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		if client.supports_method(ms.textDocument_documentHighlight) then
			local bufnr = args.buf

			local aug = augroup("liu/lsp_document_highlight" .. tostring(bufnr), { clear = false })

			do
				api.nvim_clear_autocmds({ buffer = bufnr, group = aug })

				autocmd({ "CursorHold", "CursorHoldI" }, {
					group = aug,
					buffer = bufnr,
					callback = lsp.buf.document_highlight,
				})
				autocmd({ "CursorMoved", "CursorMovedI" }, {
					group = aug,
					buffer = bufnr,
					callback = lsp.buf.clear_references,
				})

				local document_highlight = require("liu.lsp.helper").document_highlight
				keymap.set("n", "]v", document_highlight.goto_next, { buffer = bufnr })
				keymap.set("n", "[v", document_highlight.goto_prev, { buffer = bufnr })

				autocmd("LspDetach", {
					group = aug,
					callback = function()
						api.nvim_clear_autocmds({ group = aug, buffer = bufnr })
						lsp.buf.clear_references()

						keymap.del("n", "]v", { buffer = bufnr })
						keymap.del("n", "[v", { buffer = bufnr })
					end,
					buffer = bufnr,
				})
			end
		end
	end,
})
-- }}}

-- Handlers {{{2
local handlers = lsp.handlers

local old_hover = handlers[ms.textDocument_hover]
local old_signature = handlers[ms.textDocument_signatureHelp]
handlers[ms.textDocument_hover] = lsp.with(old_hover, { border = config.borders })
handlers[ms.textDocument_signatureHelp] = lsp.with(old_signature, { border = config.borders })

-- rename with notify
local old_rename = handlers[ms.textDocument_rename]
handlers[ms.textDocument_rename] = function(...)
	local function rename_notify(err, result, _, _)
		if err or not result then
			return
		end

		local changed_instances = 0
		local changed_files = 0

		local with_edits = result.documentChanges ~= nil
		for _, change in pairs(result.documentChanges or result.changes) do
			changed_instances = changed_instances + (with_edits and #change.edits or #change)
			changed_files = changed_files + 1
		end

		local message = string.format(
			"[LSP] Renamed %s instance%s in %s file%s.",
			changed_instances,
			changed_instances == 1 and "" or "s",
			changed_files,
			changed_files == 1 and "" or "s"
		)
		vim.notify(message, vim.log.levels.INFO)
	end

	old_rename(...)
	rename_notify(...)
end
-- }}}

require("liu.lsp.lightbulb")

-- vim: foldmethod=marker
