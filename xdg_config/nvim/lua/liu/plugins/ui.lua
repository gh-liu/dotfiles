return {
	{
		"nvim-mini/mini.icons",
		lazy = true,
		init = function()
			package.preload["nvim-web-devicons"] = function()
				require("mini.icons").mock_nvim_web_devicons()
				return package.loaded["nvim-web-devicons"]
			end
		end,
		opts = {
			filetype = {
				-- stylua: ignore start
				dbui             = { glyph = "󰆼", hl = "MiniIconsGrey" },
				dbout            = { glyph = "󰆼", hl = "MiniIconsGrey" },
				telescopeprompt  = { glyph = "", hl = "MiniIconsBlue" },
				-- stylua: ignore end
			},
			lsp = {
				class = { hl = "@lsp.type.class" },
				comment = { hl = "@lsp.type.comment" },
				decorator = { hl = "@lsp.type.decorator" },
				enum = { hl = "@lsp.type.enum" },
				enumMember = { hl = "@lsp.type.enumMember" },
				event = { hl = "@lsp.type.event" },
				["function"] = { glyph = "󰊕", hl = "@lsp.type.function" },
				interface = { hl = "@lsp.type.interface" },
				keyword = { hl = "@lsp.type.keyword" },
				macro = { hl = "@lsp.type.macro" },
				method = { hl = "@lsp.type.method" },
				modifier = { hl = "@lsp.type.modifier" },
				namespace = { hl = "@lsp.type.namespace" },
				number = { hl = "@lsp.type.number" },
				operator = { hl = "@lsp.type.operator" },
				parameter = { hl = "@lsp.type.parameter" },
				property = { hl = "@lsp.type.property" },
				regexp = { hl = "@lsp.type.regexp" },
				string = { hl = "@lsp.type.string" },
				struct = { hl = "@lsp.type.struct" },
				type = { hl = "@lsp.type.type" },
				typeParameter = { hl = "@lsp.type.typeParameter" },
				variable = { hl = "@lsp.type.variable" },
			},
			file = {
				["speckit.plan.md"] = { glyph = "", hl = "MiniIconsYellow" },
			},
		},
	},
	{
		"rachartier/tiny-glimmer.nvim",
		-- event = "VeryLazy",
		opts = {
			overwrite = {
				yank = {
					enabled = false,
				},
				search = {
					enabled = false,
				},
				paste = {
					enabled = true,
					default_animation = {
						name = "reverse_fade",
						settings = {
							from_color = "TinyGlimmerPaste",
						},
					},
				},
				undo = {
					enabled = true,
					default_animation = {
						name = "fade",
						settings = {
							from_color = "TinyGlimmerUndo",
						},
					},
				},
				redo = {
					enabled = true,
					default_animation = {
						name = "fade",
						settings = {
							from_color = "TinyGlimmerRedo",
						},
					},
				},
			},
		},
	},
	{
		"tpope/vim-flagship",
		init = function()
			vim.o.showtabline = 2
			-- default statusline is not empty anymore
			-- https://github.com/neovim/neovim/pull/33036
			if #vim.o.statusline > 0 then
				-- https://github.com/tpope/vim-flagship/blob/0bb6e26c31446b26900e0d38434f33ba13663cff/autoload/flagship.vim#L606
				vim.o.statusline = "%!flagship#statusline()"
			end

			-- https://github.com/tpope/vim-flagship/issues/11#issuecomment-149616002
			-- a regexp matching any flags you want to opt out of
			vim.g.flagship_skip = ""

			vim.g.tabprefix = ""
			-- vim.g.tablabel = "%N%{flagship#tabmodified()} %{flagship#tabcwds('shorten',',')}"
			vim.g.tabsuffix = ""
			-- .. "%#ModeMsg#"
			-- .. "%{v:lua.Flag_lsp_clients()}"

			vim.cmd([[
			augroup liu_flagship
			  autocmd!
			  autocmd User DAPInitialized,DAPStopped,DAPTerminated redrawtabline
			  autocmd LspProgress * redrawtabline
			  autocmd User Flags call Hoist("window", "%{&diff?'[Diff]':''}")
			  autocmd User Flags call Hoist("buffer", 11, "%{v:lua.Flag_lsp_clients()}")
			  autocmd User Flags call Hoist('buffer', 10, '%{flagship#surround( type(get(b:,"UserBufFlagship")) == 2 ? b:UserBufFlagship() : get(b:,"UserBufFlagship","") )}')
			  autocmd User Flags call Hoist("buffer", 99, "%{flagship#surround(index(argv(), bufname('%')) >= 0 ? printf('@%d/%d', index(argv(), bufname('%')) + 1, len(argv())) : '')}")
			  autocmd User Flags call Hoist("buffer", 9, "%{v:lua.Flag_diagnostic_summary()}")
			augroup END
			]])
			vim.g.tabsuffix = vim.g.tabsuffix .. "%#Debug#" .. "%{v:lua.Flag_dap_staus()}"

			-- vim.cmd([[ autocmd DiagnosticChanged * redrawtabline ]])
			-- vim.g.tabsuffix = vim.g.tabsuffix
			-- 	.. "%#DiagnosticError#"
			-- 	.. "%{v:lua.Flag_diagnostic.Get(1)}"
			-- 	.. "%#DiagnosticWarn#"
			-- 	.. "%{v:lua.Flag_diagnostic.Get(2)}"
			-- 	.. "%#DiagnosticInfo#"
			-- 	.. "%{v:lua.Flag_diagnostic.Get(3)}"
			-- 	.. "%#DiagnosticHint#"
			-- 	.. "%{v:lua.Flag_diagnostic.Get(4)}"

			vim.g.tabsuffix = "%(%{v:lua.vim.lsp.status()}%<%)" .. vim.g.tabsuffix

			local icons = require("liu.user_config").icons

			_G.Flag_sp_tab_title = function()
				-- https://github.com/tpope/vim-flagship/blob/de8da9c5e5fbb061e8ff55c65c510dcc5982c035/autoload/flagship.vim#L127
				-- Note that v:lnum is set to the tab number automatically in a tab label.
				local tabnr = vim.v.lnum
				local sp_tab_title = vim.fn.gettabvar(tabnr, "sp_tab_title", "")
				if sp_tab_title then
					return vim.fn["flagship#surround"](sp_tab_title)
				end
				return ""
			end

			_G.Flag_lsp_clients = function()
				local clients = vim.lsp.get_clients({ bufnr = 0 })
				if #clients == 0 then
					return ""
				end
				local names = {}
				for _, server in pairs(clients) do
					table.insert(names, server.name)
				end
				return "[lsp: " .. table.concat(names, " ") .. "]"
			end
			_G.Flag_dap_staus = function()
				if not package.loaded["dap"] or require("dap").status() == "" then
					return ""
				end
				-- return "[" .. icons.bug .. " " .. require("dap").status() .. "]"
				return "[" .. icons.bug .. " Debuging" .. "]"
			end
			_G.Flag_diagnostic = {
				Get = function(severity)
					local get_counts = function(buf, severity)
						local count = vim.diagnostic.count(buf, { severity = severity })
						return count[severity]
					end
					local all_counts = get_counts(nil, severity) or 0
					if all_counts == 0 then
						return ""
					end
					local local_counts = get_counts(0, severity) or 0
					return string.format(
						"%s %d/%d ",
						icons.diagnostics[vim.diagnostic.severity[severity]],
						local_counts,
						all_counts
					)
				end,
			}
			_G.Flag_diagnostic_summary = function()
				if #vim.bo.buftype > 0 then
					return ""
				end
				local get_counts = function(buf, severity)
					local count = vim.diagnostic.count(buf, { severity = severity, enabled = true })
					return count[severity]
				end

				local summary_strs = {}
				local diag = {
					E = vim.diagnostic.severity.ERROR,
					W = vim.diagnostic.severity.WARN,
					I = vim.diagnostic.severity.INFO,
					H = vim.diagnostic.severity.HINT,
				}
				for key, serverity in pairs(diag) do
					local count = get_counts(0, serverity)
					if count and count > 0 then
						table.insert(summary_strs, key .. ":" .. tostring(count))
					end
				end
				if #summary_strs > 0 then
					table.sort(summary_strs, function(str1, str2)
						local l1 = string.sub(str1, 1, 1)
						local l2 = string.sub(str2, 1, 1)
						return diag[l1] > diag[l2]
					end)
					return vim.fn["flagship#surround"](vim.iter(summary_strs):join(" "))
				end
				return ""
			end
			-- "autocmd User Flags call Hoist("buffer", "fugitive#statusline")
			-- "autocmd User Flags call Hoist("window", "%-13a") " argument
			-- "autocmd User Flags call Hoist("window", "%{&previewwindow?'[PVW]':''}")
			-- "autocmd User Flags call Hoist("global", "%{&ignorecase ? '[IC]' : ''}", {'hl': 'ModeMsg'})
			-- "autocmd User Flags call Hoist("buffer", 12, "%{&channel?flagship#surround('channel:'.&channel):''}")
			-- "autocmd User Flags call Hoist("buffer", 99, "%{flagship#surround(index(argv(), bufname('%')) >= 0 ? 'A+' : '')}")
			-- "autocmd User Flags call Hoist("tabpage", "%{v:lua.Flag_sp_tab_title()}")
			-- if vim.diagnostic.status then
			-- 	vim.cmd(
			-- 		[[ autocmd User Flags call Hoist("buffer", 9, "%{flagship#surround(v:lua.vim.diagnostic.status())}") ]]
			-- 	)
			-- else
			-- 	vim.cmd([[ autocmd User Flags call Hoist("buffer", 9, "%{v:lua.Flag_diagnostic_summary()}") ]])
			-- end

			if vim.fn.exists("&busy") then
				vim.cmd([[ autocmd User Flags call Hoist("buffer", 99, "%{&busy>0?flagship#surround('…'):''}") ]])
			end
		end,
	},
	{
		"gh-liu/fold_line.nvim",
		enabled = false,
		-- dev = true,
		branch = "dev",
		event = "VeryLazy",
		init = function()
			vim.g.fold_line_char_open_start = "╭"
			vim.g.fold_line_char_open_end = "╰"

			-- vim.g.fold_line_current_fold_only = true
		end,
	},
}
