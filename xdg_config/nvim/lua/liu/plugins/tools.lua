-- NOTE: not editor features?
return {
	{
		"olimorris/codecompanion.nvim",
		-- event = "VeryLazy",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				-- @need-install: bun install -g mcp-hub@latest
				"ravitemer/mcphub.nvim",
				opts = {
					workspace = {
						look_for = {
							-- https://code.visualstudio.com/docs/copilot/chat/mcp-servers#_configuration-format
							".git/mcp.json",
							".vscode/mcp.json",
							".cursor/mcp.json",
						},
					},
				},
			},
		},
		init = function()
			vim.cmd([[
				cab cc  CodeCompanion
				cab ccc CodeCompanionChat
				cab cca CodeCompanionActions

				autocmd BufWinEnter *CodeCompanion* setlocal stl=[]CodeCompanion
			]])
		end,
		opts = {
			adapters = {
				http = {
					openai = function()
						return require("codecompanion.adapters").extend("openai_compatible", {
							env = {
								url = "OPENAI_BASE_URL",
								-- api_key = "OPENAI_API_KEY",
							},
						})
					end,
					anthropic = function()
						local base_url = vim.env.ANTHROPIC_BASE_URL or "https://api.anthropic.com"
						return require("codecompanion.adapters").extend("anthropic", {
							url = string.format("%s/v1/messages", base_url),
						})
					end,
				},
				acp = {},
			},
			strategies = {
				chat = {
					---@alias liu.Provider "claude" | "openai" | "gemini" | "copilot" | "deepseek" | string
					---@type liu.Provider
					adapter = "deepseek",
					keymaps = {
						options = {
							modes = { n = "g?" },
						},
						stop = {
							modes = { n = "gq" },
						},
						completion = {
							modes = {
								i = "<plug>(codecompanion.completion)",
							},
						},
						close = {
							modes = {
								n = "<localleader>c",
								i = "<plug>(codecompanion.close)",
							},
						},
					},
				},
				inline = {
					---@type liu.Provider
					adapter = "deepseek",
				},
				cmd = {
					---@type liu.Provider
					adapter = "deepseek",
				},
			},
			extensions = {
				mcphub = {
					-- https://ravitemer.github.io/mcphub.nvim/extensions/codecompanion.html#mcp-hub-extension
					callback = "mcphub.extensions.codecompanion",
					opts = {
						-- MCP Tools
						make_tools = true, -- Make individual tools (@server__tool) and server groups (@server) from MCP servers
						show_server_tools_in_chat = true, -- Show individual tools in chat completion (when make_tools=true)
						add_mcp_prefix_to_tool_names = false, -- Add mcp__ prefix (e.g `@mcp__github`, `@mcp__neovim__list_issues`)
						show_result_in_chat = true, -- Show tool results directly in chat buffer
						format_tool = nil, -- function(tool_name:string, tool: CodeCompanion.Agent.Tool) : string Function to format tool names to show in the chat buffer
						-- MCP Resources
						make_vars = true, -- Convert MCP resources to #variables for prompts
						-- MCP Prompts
						make_slash_commands = true, -- Add MCP prompts as /slash commands
					},
				},
			},
		},
		keys = {
			{ "yuc", "<cmd>CodeCompanionChat toggle<cr>" },
		},
		cmd = {
			"CodeCompanion",
			"CodeCompanionChat",
			"CodeCompanionActions",
		},
	},
	{
		"yetone/avante.nvim",
		enabled = false,
		build = "make",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"nvim-lua/plenary.nvim",
		},
		opts = {
			---@alias Provider "claude" | "openai" | "gemini" | "copilot" | "deepseek" | string
			---@type Provider
			provider = "deepseek",
			---@type Provider
			auto_suggestions_provider = "deepseek",
			providers = {
				deepseek = {
					__inherited_from = "openai",
					api_key_name = "DEEPSEEK_API_KEY",
					endpoint = "https://api.deepseek.com",
					model = "deepseek-coder",
				},
			},
			behaviour = {
				auto_suggestions = false,
			},
		},
	},
	{
		"milanglacier/minuet-ai.nvim",
		enabled = false,
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		opts = {
			virtualtext = {
				auto_trigger_ft = { "*" },
				auto_trigger_ignore_ft = { "codecompanion" },
				keymap = {
					-- accept whole completion
					accept = "<A-A>",
					-- accept one line
					accept_line = "<A-a>",
					-- accept n lines (prompts for number)
					-- e.g. "A-z 2 CR" will accept 2 lines
					accept_n_lines = "<A-z>",
					-- Cycle to prev completion item, or manually invoke completion
					prev = "<A-[>",
					-- Cycle to next completion item, or manually invoke completion
					next = "<A-]>",
					dismiss = "<A-e>",
				},
			},
			provider = "openai_compatible",
			n_completions = 1,
			context_window = 512,
			provider_options = {
				-- https://ollama.readthedocs.io/en/openai/#endpoints
				-- openai_compatible = {
				-- 	api_key = "TERM",
				-- 	name = "Ollama",
				-- 	end_point = "http://localhost:11434/v1/chat/completions",
				-- 	model = "qwen2.5-coder:7b",
				-- 	optional = {
				-- 		max_tokens = 56,
				-- 		top_p = 0.9,
				-- 	},
				-- },
				openai_compatible = {
					end_point = (os.getenv("OPENAI_BASE_URL") or "https://api.openai.com") .. "/v1/chat/completions",
					model = "gpt-4.1-mini",
					api_key = "OPENAI_API_KEY",
					optional = { max_tokens = 128, top_p = 0.9 },
				},
				-- openai_compatible = {
				-- 	end_point = "https://api.deepseek.com/chat/completions",
				-- 	api_key = "DEEPSEEK_API_KEY",
				-- 	name = "deepseek",
				-- 	model = "deepseek-chat",
				-- 	optional = {
				-- 		max_tokens = 256,
				-- 		top_p = 0.9,
				-- 	},
				-- },
			},
			cmp = {
				enable_auto_complete = false,
			},
			blink = {
				enable_auto_complete = false,
			},
		},
	},
	{
		"tpope/vim-dadbod",
		init = function()
			-- vim.keymap.set("n", "dq", "db#op_exec()", { expr = true })

			vim.cmd([[
			    xnoremap <expr> <Plug>(DBExe)     db#op_exec()
				nnoremap <expr> <Plug>(DBExe)     db#op_exec()
				nnoremap <expr> <Plug>(DBExeLine) db#op_exec() . '_'
				
				xmap dq  <Plug>(DBExe)
				nmap dq  <Plug>(DBExe)
				omap dq  <Plug>(DBExe)
				nmap dqq <Plug>(DBExeLine)

				nmap dq? <cmd> echo get(g:,"db",get(b:,"db","no db")) <cr>
			]])

			-- NOTE: define your adapters:
			-- use `g:db_adapter_ADAPTERNAME` to define methods of you adapter
			-- https://github.com/tpope/vim-dadbod/blob/e95afed23712f969f83b4857a24cf9d59114c2e6/autoload/db/adapter.vim#L14
			-- call adapter methods by `db#adapter#call(arg1, adapter_method, ...)`
		end,
	},
	{
		"tpope/vim-tbone",
		enabled = false,
		-- event = "VeryLazy",
	},
	{
		"mistweaverco/kulala.nvim",
		-- @need-install: go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
		-- @need-install: cargo install websocat
		init = function()
			vim.api.nvim_create_autocmd({ "FileType" }, {
				pattern = "http",
				callback = function(ev)
					local buffer = ev.buf
					vim.keymap.set("n", "[[", require("kulala").jump_prev, { buffer = buffer })
					vim.keymap.set("n", "]]", require("kulala").jump_next, { buffer = buffer })

					vim.keymap.set("n", "<localleader>r", require("kulala").run, { buffer = buffer })
					vim.keymap.set("n", "<localleader>R", require("kulala").replay, { buffer = buffer })
					vim.keymap.set("n", "<localleader>cc", require("kulala").copy, { buffer = buffer })
					vim.keymap.set("n", "<localleader>se", require("kulala").set_selected_env, { buffer = buffer })

					vim.b.dispatch = [[:lua require("kulala").run()]]

					vim.b.UserBufFlagship = function()
						local CONFIG = require("kulala.config")
						-- return "kulala:" .. (vim.g.kulala_selected_env or CONFIG.get().default_env)
						local icon = CONFIG.get().icons.lualine
						return icon .. (vim.g.kulala_selected_env or CONFIG.get().default_env)
					end

					vim.t.sp_tab_title = "kulala"
				end,
			})

			vim.api.nvim_create_autocmd("BufEnter", {
				pattern = "kulala://ui",
				callback = function(data)
					if vim.fn.winnr("$") < 2 then
						vim.cmd.bdelete({ bang = true, mods = { silent = true } })
					end
				end,
			})
		end,
		ft = { "http" },
		opts = {
			global_keymaps = false,
			-- https://neovim.getkulala.net/docs/getting-started/configuration-options#certificates
			certificates = {},
			custom_dynamic_variables = {}, ---@type { [string]: fun():string }[]
		},
	},
	{
		"uga-rosa/ccc.nvim",
		cmd = { "CccPick", "CccHighlighterToggle" },
		config = function()
			local ccc = require("ccc")
			ccc.setup({
				highlighter = {
					auto_enable = true,
					lsp = true,
				},
			})
		end,
	},
	{
		"dhananjaylatkar/cscope_maps.nvim",
		enabled = false,
		opts = {
			disable_maps = true,
			prefix = false,
		},
		cmd = { "Cs" },
	},
	{
		"brianhuster/unnest.nvim",
	},
	-- filetype plugins below
}
