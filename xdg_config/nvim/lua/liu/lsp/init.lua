local api = vim.api
local lsp = vim.lsp
local lsp_methods = vim.lsp.protocol.Methods ---@type vim.lsp.protocol.Methods

-- commands {{{
vim.api.nvim_create_user_command("LspClientCapabilities", function(opts)
	local client = vim.lsp.get_clients({ name = opts.fargs[1] })[1]
	if not client then
		return
	end
	vim.print(client.capabilities)
end, {
	nargs = 1,
	complete = function()
		return vim.iter(vim.lsp.get_clients({ bufnr = 0 }))
			:map(function(client)
				return client.name
			end)
			:totable()
	end,
})

vim.api.nvim_create_user_command("LspSetLogLevel", function(opts)
	local level = unpack(opts.fargs)
	vim.lsp.log.set_level(level)
	vim.notify("Set: " .. level, vim.log.levels.INFO)
end, {
	desc = "Set Lsp Log Level",
	nargs = 1,
	complete = function()
		return vim.iter(vim.log.levels)
			:map(function(k, v)
				return k
			end)
			:totable()
	end,
})
--}}}

-- feats {{{1
api.nvim_create_autocmd("LspAttach", {
	group = api.nvim_create_augroup("liu/lsp_feat", { clear = true }),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		local bufnr = args.buf

		if client:supports_method(lsp_methods.textDocument_codeLens) then
			local codelens_group = api.nvim_create_augroup("liu/lsp_codelens/" .. bufnr, { clear = true })
			api.nvim_create_autocmd({ "CursorHold", "InsertLeave" }, {
				group = codelens_group,
				callback = function(ev)
					lsp.codelens.refresh({ bufnr = bufnr })
				end,
				buffer = bufnr,
			})
		end

		if client:supports_method(lsp_methods.textDocument_inlayHint) then
			local filter = { bufnr = bufnr }
			lsp.inlay_hint.enable(true, filter)
		end

		if lsp.foldexpr and client:supports_method(lsp_methods.textDocument_foldingRange) then
			if vim.wo[0][0].foldmethod ~= "expr" then
				vim.wo[0][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
				vim.wo[0][0].foldmethod = "expr"
				-- vim.wo[0][0].foldtext = "v:lua.vim.lsp.foldtext()"
			end
		end

		if lsp.document_color and client:supports_method(lsp_methods.textDocument_documentColor) then
			lsp.document_color.enable(true, bufnr, { style = "virtual" })
		end

		if lsp.on_type_formatting and client:supports_method(lsp_methods.textDocument_onTypeFormatting) then
			lsp.on_type_formatting.enable(true, { client_id = client.id })
		end

		if lsp.linked_editing_range and client:supports_method(lsp_methods.textDocument_linkedEditingRange) then
			lsp.linked_editing_range.enable(true, { client_id = client.id })
		end

		if lsp.completion and client:supports_method(lsp_methods.textDocument_completion) then
			-- lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
		end

		if lsp.inline_completion and client:supports_method(lsp_methods.textDocument_inlineCompletion) then
			local filter = { client_id = client.id }
			if not lsp.inline_completion.is_enabled(filter) then
				lsp.inline_completion.enable(true, filter)
			end
			-- vim.keymap.set("i", "<Tab>", function()
			-- 	if not vim.lsp.inline_completion.get() then
			-- 		return "<Tab>"
			-- 	end
			-- end, { buffer = bufnr, expr = true, desc = "Accept the current inline completion" })
			vim.keymap.set("i", "<C-X><C-C>", function()
				vim.lsp.inline_completion.select()
			end, { buffer = bufnr })
		end
	end,
})
--}}}

-- on list {{{1
local function on_list(items)
	if #items.items == 1 then
		local bufnr = items.context.bufnr
		local method = items.context.method
		local clients = lsp.get_clients({ method = method, bufnr = bufnr })
		local item = items.items[1]
		local loc = item.user_data ---@type lsp.Location
		-- if vim.uri_from_bufnr(bufnr) == loc.uri then
		-- vim.cmd("vsplit")
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
			lsp.buf.declaration({ on_list = on_list })
		end, "[G]oto [D]eclaration")
		nmap("gd", function()
			lsp.buf.definition({ on_list = on_list })
		end, "[G]oto [D]efinition")
		nmap("gy", function()
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

		-- vim.keymap.set("i", "<C-]>", lsp.buf.signature_help, { buffer = bufnr, desc = "Signature Documentation" })
	end,
})
-- }}}

-- handlers {{{1
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
local old_rename = handlers[lsp_methods.textDocument_rename]
handlers[lsp_methods.textDocument_rename] = function(...)
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

-- tools setup/on_attach {{{1
local on_attachs = {}
local tool_dir = "liu/lsp/tools/"
local require_prefix = tool_dir:gsub("/", ".")
for _, file in ipairs(vim.fn.readdir(vim.fn.stdpath("config") .. "/lua/" .. tool_dir, [[v:val =~ '\.lua$']])) do
	local m = require(require_prefix .. file:gsub("%.lua$", ""))
	if m then
		if m.setup then
			m.setup()
		end
		if m.on_attach then
			table.insert(on_attachs, m.on_attach)
		end
	end
end

api.nvim_create_autocmd("LspAttach", {
	group = api.nvim_create_augroup("liu/lsp_tools", { clear = true }),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end

		for _, on_attach in ipairs(on_attachs) do
			on_attach(client, args.buf)
		end
	end,
})
-- }}}

vim.lsp.start = (function()
	local old_lsp_start = vim.lsp.start
	return function(...)
		local _, opt = unpack({ ... })
		if opt and opt.bufnr then
			if
				not vim.api.nvim_buf_is_valid(opt.bufnr)
				or vim.b[opt.bufnr].fugitive_type
				or vim.startswith(vim.api.nvim_buf_get_name(opt.bufnr), "fugitive://")
			then
				return
			end
		end
		old_lsp_start(...)
	end
end)()

vim.api.nvim_create_autocmd("LspProgress", {
	callback = function(ev)
		local value = ev.data.params.value
		if value.kind == "begin" then
			vim.api.nvim_ui_send("\027]9;4;1;0\027\\")
		elseif value.kind == "end" then
			vim.api.nvim_ui_send("\027]9;4;0\027\\")
		elseif value.kind == "report" then
			vim.api.nvim_ui_send(string.format("\027]9;4;1;%d\027\\", value.percentage or 0))
		end
	end,
})

vim.api.nvim_create_autocmd("LspRequest", {
	callback = function(args)
		local bufnr = args.buf
		local request = args.data.request
		if request.type == "pending" then
			vim.bo[bufnr].busy = 1
		elseif request.type == "cancel" then
			vim.bo[bufnr].busy = 0
		elseif request.type == "complete" then
			vim.bo[bufnr].busy = 0
		end
	end,
})

vim.lsp.enable("gopls")
vim.lsp.enable({
	-- "pyright"
	-- "basedpyright",
	"ruff", -- formating/linting
	"ty",
})
if vim.fn.executable("emmylua_ls") == 1 then
	vim.lsp.enable({ "emmylua_ls" })
else
	vim.lsp.enable("lua_ls")
end
vim.lsp.enable("rust_analyzer")
vim.lsp.enable("zls")
vim.lsp.enable("ts_ls")
vim.lsp.enable("bashls")
vim.lsp.enable("vimls")
vim.lsp.enable({ "jsonls", "yamlls", "taplo" })
vim.lsp.enable("clangd")
-- vim.lsp.enable("ast_grep")
vim.lsp.enable("buf_ls")
-- vim.lsp.enable("dockerls")
vim.lsp.enable("docker_language_server")
vim.lsp.enable("terraformls")
vim.lsp.enable("nushell")

-- vim.lsp.enable({ "copilot" })

-- if vim.fn.executable("gideon") == 1 then
-- 	vim.lsp.enable({ "gideon" })
-- end

-- vim: foldmethod=marker
