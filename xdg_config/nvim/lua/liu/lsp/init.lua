local api = vim.api
local lsp = vim.lsp

local old_lsp_start = vim.lsp.start

vim.lsp.start = function(...)
	local _, opt = unpack({ ... })
	if opt and opt.bufnr then
		if vim.api.nvim_buf_is_valid(opt.bufnr) and vim.b[opt.bufnr].fugitive_type then
			return
		end
	end
	old_lsp_start(...)
end

-- Log Levels {{{1
api.nvim_create_user_command("LspSetLogLevel", function(opts)
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

-- on list {{{1
local function on_list(items)
	if #items.items == 1 then
		local bufnr = items.context.bufnr
		local method = items.context.method
		local clients = lsp.get_clients({ method = method, bufnr = bufnr })
		local item = items.items[1]
		local loc = item.user_data ---@type lsp.Location
		-- if vim.uri_from_bufnr(bufnr) == loc.uri then
		vim.cmd("vsplit")
		vim.lsp.util.show_document(loc, clients[1].offset_encoding, { focus = true })
		return
		-- end
	end

	vim.fn.setqflist({}, " ", items)
	if #items.items > 1 then
		-- vim.notify("Multiple items found, opening first one", vim.log.levels.INFO)
		-- vim.cmd.copen()
		vim.cmd("botright copen")
		-- vim.cmd.cfirst()
		vim.cmd("normal zz")
	end
end
-- }}}

-- keymaps {{{1
api.nvim_create_autocmd("LspAttach", {
	group = api.nvim_create_augroup("liu/lsp_keymaps", { clear = true }),
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
			vim.keymap.set("n", lhs, func, { buffer = bufnr, desc = desc })
		end

		nmap("gD", function()
			vim.cmd("normal mJ")
			lsp.buf.declaration({ on_list = on_list })
		end, "[G]oto [D]eclaration")
		nmap("gd", function()
			vim.cmd("normal mJ")
			lsp.buf.definition({ on_list = on_list })
		end, "[G]oto [D]efinition")
		nmap("gy", function()
			vim.cmd("normal mJ")
			lsp.buf.type_definition({ on_list = on_list })
		end, "[G]oto T[y]pe Definition")

		-- NOTE: default mapping for references: gri
		-- nmap("gi", function()
		-- 	lsp.buf.implementation({ on_list = on_list })
		-- end, "[G]oto [I]mplementation")

		-- NOTE: default mapping for references: grr
		-- nmap("gr", function()
		-- 	lsp.buf.references(nil, { on_list = on_list })
		-- end, "[G]oto [R]eferences")

		-- nmap("K", lsp.buf.hover, "Hover Documentation")

		-- NOTE: default mapping for rename: grn
		-- if client:supports_method(ms.textDocument_rename) then
		-- 	nmap("crn", lsp.buf.rename, "[R]e[n]ame")
		-- end

		-- NOTE: default lsp mapping prefix with `gr`
		nmap("grl", lsp.codelens.run, "Code [L]en")

		vim.keymap.set("i", "<C-]>", lsp.buf.signature_help, { buffer = bufnr, desc = "Signature Documentation" })
	end,
})
-- }}}

api.nvim_create_autocmd("LspAttach", {
	group = api.nvim_create_augroup("liu/lsp_feat", { clear = true }),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		local bufnr = args.buf
		-- codelens {{{1
		if client and client:supports_method("textDocument/codeLens") then
			api.nvim_create_autocmd({ "CursorHold", "InsertLeave" }, {
				callback = function(ev)
					lsp.codelens.refresh({ bufnr = ev.buf })
				end,
				buffer = bufnr,
			})
		end
		-- }}}

		-- inlayhint {{{1
		if client:supports_method("textDocument/inlayHint") then
			local bufnr = args.buf
			local inlay_hint = lsp.inlay_hint

			local filter = { bufnr = bufnr }
			inlay_hint.enable(true, filter)

			vim.keymap.set("n", "yoI", function()
				inlay_hint.enable(not inlay_hint.is_enabled(filter), filter)
			end, { buffer = bufnr })

			-- api.nvim_buf_create_user_command(bufnr, "InlayHintToggle", function(opts)
			-- 	inlay_hint.enable(not inlay_hint.is_enabled(filter), filter)
			-- end, { nargs = 0 })

			api.nvim_buf_create_user_command(bufnr, "InlayHintRefresh", function(opts)
				inlay_hint.enable(false, filter)
				inlay_hint.enable(true, filter)
			end, { nargs = 0 })
		end
		-- }}}

		-- folding {{{1
		if lsp.foldexpr then
			if client:supports_method("textDocument/foldingRange") then
				vim.wo[0][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
				-- set_local_default("foldexpr", "v:lua.vim.lsp.foldexpr()")
				-- vim.wo[0][0].foldtext = "v:lua.vim.lsp.foldtext()"
			end
		end
		-- }}}

		-- document_color {{{1
		if lsp.document_color then
			if client:supports_method("textDocument/documentColor") then
				lsp.document_color.enable(true, bufnr, { style = "virtual" })
			end
		end
		-- }}}
	end,
})
-- semantic tokens
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "gotmpl" },
	callback = function()
		vim.lsp.semantic_tokens.enable(false, { bufnr = 0 })
	end,
})

--- set the local value only when the global value is not set
---@param name string
---@param value any
local function set_local_default(name, value)
	if
		vim.api.nvim_get_option_value(name, { scope = "global" })
		== vim.api.nvim_get_option_info2(name, { scope = "global" }).default
	then
		vim.api.nvim_set_option_value(name, value, { scope = "local" })
	end
end

local ms = lsp.protocol.Methods
-- Handlers {{{1
local function with(f, config)
	return function(c)
		return f(vim.tbl_deep_extend("force", config, c or {}))
	end
end

local old_references = vim.lsp.buf.references
---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.buf.references = function(ctx, opts)
	old_references(ctx, vim.tbl_deep_extend("force", opts or {}, { on_list = on_list }))
end

vim.lsp.buf.implementation = with(vim.lsp.buf.implementation, { on_list = on_list })

local handlers = lsp.handlers

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

api.nvim_create_autocmd("LspAttach", {
	group = api.nvim_create_augroup("liu/lsp_tools", { clear = true }),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		local tool_dir = "liu/lsp/tools/"
		local require_prefix = tool_dir:gsub("/", ".")

		for _, file in ipairs(vim.fn.readdir(vim.fn.stdpath("config") .. "/lua/" .. tool_dir, [[v:val =~ '\.lua$']])) do
			require(require_prefix .. file:gsub("%.lua$", "")).on_attach(client, args.buf)
		end
	end,
})

vim.lsp.enable("gopls")
if vim.fn.executable("emmylua_ls") == 1 then
	vim.lsp.enable({ "emmylua_ls" })
else
	vim.lsp.enable("lua_ls")
end
vim.lsp.enable({ "ruff", "basedpyright" })
vim.lsp.enable({ "jsonls", "yamlls", "taplo" })
vim.lsp.enable("clangd")
vim.lsp.enable("ast_grep")
vim.lsp.enable("buf_ls")
-- vim.lsp.enable("dockerls")
vim.lsp.enable("docker_language_server")
vim.lsp.enable("terraformls")
vim.lsp.enable("nushell")
-- vim: foldmethod=marker
