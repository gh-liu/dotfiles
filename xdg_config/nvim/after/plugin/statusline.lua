if false then
	return
end

local api = vim.api
local fn = vim.fn

local icons = config.icons
local colors = config.colors

-- Do not display the command that produced the quickfix list.
-- https://neovim.io/doc/user/filetype.html#ft-qf-plugin
vim.g.qf_disable_statusline = 1

local M = {}

---@class color
---@field fg string
---@field bg string

---extract highlight
---@param highlight string
---@return color|nil
local extract_highlight_colors = function(highlight)
	if fn.hlexists(highlight) == 0 then
		return nil
	end
	local hl = api.nvim_get_hl(0, { name = highlight })
	local bg = hl.bg and ("#%06x"):format(hl.bg) or nil
	local fg = hl.fg and ("#%06x"):format(hl.fg) or nil
	return {
		bg = bg,
		fg = fg,
	}
end

local status_line_bg = extract_highlight_colors("StatusLine").bg

---@type table<string, boolean>
local statusline_hls = {}

---@param hl string
---@return string
function M.get_or_create_hl(hl)
	local hl_name = "Statusline" .. hl

	if not statusline_hls[hl] then
		local fg = extract_highlight_colors(hl).fg
		api.nvim_set_hl(0, hl_name, { bg = status_line_bg, fg = fg })
		statusline_hls[hl] = true
	end

	return hl_name
end

local separator_name = "StatuslineSeparator"
api.nvim_set_hl(0, separator_name, { bg = status_line_bg, fg = colors.gray })
local separator = string.format("%%#%s#%s", separator_name, "|")

local mode_colors = {
	ModeNormal = colors.red,
	ModePENDING = colors.magenta,
	ModeVisual = colors.blue,
	ModeInsert = colors.green,
	ModeSELECT = colors.magenta,
	ModeCOMMAND = colors.orange,
	ModeTERMINAL = colors.cyan,
	ModeEX = colors.yellow,
	ModeREPLACE = colors.cyan,
	ModeUNKNOWN = colors.gray,
}
for k, v in pairs(mode_colors) do
	api.nvim_set_hl(0, "Statusline" .. k, { fg = v, bg = status_line_bg })
end

--- Current mode.
---@return string
function M.mode_component()
	-- Note that: \19 = ^S and \22 = ^V.
	local mode_to_str = {
		["n"] = "NORMAL",
		["no"] = "OP-PENDING",
		["nov"] = "OP-PENDING",
		["noV"] = "OP-PENDING",
		["no\22"] = "OP-PENDING",
		["niI"] = "NORMAL",
		["niR"] = "NORMAL",
		["niV"] = "NORMAL",
		["nt"] = "NORMAL",
		["ntT"] = "NORMAL",
		["v"] = "VISUAL",
		["vs"] = "VISUAL",
		["V"] = "VISUAL",
		["Vs"] = "VISUAL",
		["\22"] = "VISUAL",
		["\22s"] = "VISUAL",
		["s"] = "SELECT",
		["S"] = "SELECT",
		["\19"] = "SELECT",
		["i"] = "INSERT",
		["ic"] = "INSERT",
		["ix"] = "INSERT",
		["R"] = "REPLACE",
		["Rc"] = "REPLACE",
		["Rx"] = "REPLACE",
		["Rv"] = "VIRT REPLACE",
		["Rvc"] = "VIRT REPLACE",
		["Rvx"] = "VIRT REPLACE",
		["c"] = "COMMAND",
		["cv"] = "VIM EX",
		["ce"] = "EX",
		["r"] = "PROMPT",
		["rm"] = "MORE",
		["r?"] = "CONFIRM",
		["!"] = "SHELL",
		["t"] = "TERMINAL",
	}

	local mode = mode_to_str[api.nvim_get_mode().mode] or "UNKNOWN"

	local hl = "ModeUNKNOWN"
	if mode:find("NORMAL") then
		hl = "ModeNormal"
	elseif mode:find("PENDING") then
		hl = "ModePending"
	elseif mode:find("VISUAL") then
		hl = "ModeVisual"
	elseif mode:find("INSERT") then
		hl = "ModeInsert"
	elseif mode:find("SELECT") then
		hl = "ModeSELECT"
	elseif mode:find("COMMAND") then
		hl = "ModeCommand"
	elseif mode:find("TERMINAL") then
		hl = "ModeTERMINAL"
	elseif mode:find("EX") then
		hl = "ModeEX"
	elseif mode:find("REPLACE") then
		hl = "ModeREPLACE"
	end

	return table.concat({
		string.format("%%#Statusline%s#%s", hl, mode),
		separator,
	})
end

function M.work_dir_component()
	local icon = (fn.haslocaldir(0) == 1 and "l" or "g") .. " " .. icons.directory
	local cwd = fn.pathshorten(fn.getcwd(0))

	return table.concat({
		string.format("%%#%s#%s%s", M.get_or_create_hl("Directory"), icon, "%<" .. cwd),
		separator,
	})
end

function M.special_file_type_component()
	return string.format("%%#%s#%s", M.get_or_create_hl("MoreMsg"), string.upper(vim.bo.filetype))
end

function M.file_name_component()
	local result = {}

	local filename = api.nvim_buf_get_name(0)
	if filename == "" then
		filename = "[No Name]"
	else
		-- local extension = fn.fnamemodify(filename, ":e")
		-- local icon, icon_color = require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })

		filename = fn.fnamemodify(filename, ":.")
	end
	table.insert(result, string.format("%%#%s#%s", M.get_or_create_hl("Normal"), filename))

	if vim.bo.modified then
		table.insert(result, string.format("%%#%s#%s", M.get_or_create_hl("ErrorMsg"), "[+]"))
	end
	if not vim.bo.modifiable or vim.bo.readonly then
		table.insert(result, string.format("%%#%s#%s", M.get_or_create_hl("WarningMsg"), ""))
	end

	if vim.wo.diff then
		table.insert(result, string.format("%%#%s# %s", M.get_or_create_hl("ErrorMsg"), "[D]"))
	end

	return table.concat(result)
end

--- Git status (if any).
---@return string
function M.git_component()
	local head = vim.b.gitsigns_head
	if not head then
		return ""
	end

	return string.format("%%#%s#%s %s", M.get_or_create_hl("DiffText"), icons.git, head)
end

--- Lsp clients (if any).
---@return string
function M.lsp_clients_component()
	local names = {}
	for _, server in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
		table.insert(names, server.name)
	end
	if #names == 0 then
		return ""
	end
	local clients = "[" .. table.concat(names, " ") .. "]"

	return string.format("%%#%s#%s%s", M.get_or_create_hl("MoreMsg"), " ", clients)
end

--- Lsp progress status (if any).
---@type table<string, string?>
local progress_status = {
	client = nil,
	kind = nil,
	title = nil,
}

api.nvim_create_autocmd("LspProgress", {
	group = api.nvim_create_augroup("liu_statusline", { clear = true }),
	desc = "Update LSP progress in statusline",
	pattern = { "begin", "end" },
	callback = function(args)
		-- This should in theory never happen, but I've seen weird errors.
		if not args.data then
			return
		end

		progress_status = {
			client = vim.lsp.get_client_by_id(args.data.client_id).name,
			kind = args.data.result.value.kind,
			title = args.data.result.value.title,
		}

		if progress_status.kind == "end" then
			progress_status.title = nil
			-- Wait a bit before clearing the status.
			vim.defer_fn(function()
				vim.cmd.redrawstatus()
			end, 3000)
		else
			vim.cmd.redrawstatus()
		end
	end,
})
--- The latest LSP progress message.
---@return string
function M.lsp_progress_component()
	if not progress_status.client or not progress_status.title then
		return ""
	end

	return table.concat({
		string.format("%%#%s#%s: ", M.get_or_create_hl("Title"), progress_status.client),
		string.format("%%#%s#%s...", M.get_or_create_hl("Normal"), progress_status.title),
	})
end

--- The current debugging status (if any).
---@return string?
function M.dap_component()
	if not package.loaded["dap"] or require("dap").status() == "" then
		return nil
	end

	return table.concat({
		string.format("%%#%s#%s %s", M.get_or_create_hl("Debug"), icons.bug, require("dap").status()),
		separator,
	})
end

local last_diagnostic_component = ""

--- Diagnostic counts in the current buffer.
---@return string
function M.diagnostics_component()
	-- Use the last computed value if in insert mode.
	if vim.startswith(api.nvim_get_mode().mode, "i") then
		return last_diagnostic_component
	end

	local count_fn = function(buf)
		return vim.iter(vim.diagnostic.get(buf)):fold({
			ERROR = 0,
			WARN = 0,
			INFO = 0,
			HINT = 0,
		}, function(acc, diagnostic)
			local severity = vim.diagnostic.severity[diagnostic.severity]
			acc[severity] = acc[severity] + 1
			return acc
		end)
	end

	local all_counts = count_fn(nil)
	local local_counts = count_fn(0)
	local parts = {}
	for severity, count in pairs(all_counts) do
		if count > 0 then
			local hl = "Diagnostic" .. severity:sub(1, 1) .. severity:sub(2):lower()
			table.insert(
				parts,
				string.format(
					"%%#%s#%s %d/%d",
					M.get_or_create_hl(hl),
					icons.diagnostics[severity],
					local_counts[severity],
					count
				)
			)
		end
	end
	-- local parts = vim.iter.map(function(severity, count)
	-- 	if count == 0 then
	-- 		return nil
	-- 	end

	-- 	local hl = "Diagnostic" .. severity:sub(1, 1) .. severity:sub(2):lower()
	-- 	return string.format("%%#%s#%s %d", M.get_or_create_hl(hl), icons.diagnostics[severity], count)
	-- end, counts)

	return table.concat(parts, " ")
end

--- The buffer's filetype.
---@return string
function M.filetype_component()
	local filetype = vim.bo.filetype
	if filetype == "" then
		return ""
	end

	local bufname = api.nvim_buf_get_name(0)
	local ext = fn.fnamemodify(bufname, ":e")

	local devicons = require("nvim-web-devicons")
	local icon, icon_hl = devicons.get_icon_by_filetype(filetype, { default = true })
	icon_hl = M.get_or_create_hl(icon_hl)

	return string.format("%%#%s#%s %%#%s#%s", icon_hl, icon, icon_hl, filetype)
end

--- File-content encoding for the current buffer.
---@return string
function M.encoding_component()
	local encoding = vim.opt.fileencoding:get()
	return encoding ~= "" and string.format("%%#%s#%s", M.get_or_create_hl("Normal"), encoding) or ""
end

--- The current line, total line count, and column position.
---@return string
function M.position_component()
	local line = fn.line(".")
	local line_count = api.nvim_buf_line_count(0)
	local col = fn.virtcol(".")

	local len = #tostring(line_count)
	local line = string.format("%" .. len .. "d", line)

	return table.concat({
		string.format("%%#%s#l: %%#%s#%s", M.get_or_create_hl("Normal"), M.get_or_create_hl("Search"), line),
		string.format("%%#%s#/%d c: %d", M.get_or_create_hl("Normal"), line_count, col),
	})
end

function M.preview_window()
	if vim.wo.previewwindow then
		return "%w"
	else
		return ""
	end
end

--- Renders the statusline.
---@return string
function M.render()
	---@param components string[]
	---@return string
	local function concat_components(components)
		return vim.iter(components):skip(1):fold(components[1], function(acc, component)
			return #component > 0 and string.format("%s %s", acc, component) or acc
		end)
	end

	if vim.bo.filetype == "qf" then
		return table.concat({
			concat_components({
				M.special_file_type_component(),
			}),
			" %q",
			"%#StatusLine#%=",
			concat_components({
				M.position_component(),
			}),
		})
	end

	if vim.bo.filetype == "help" then
		return table.concat({
			concat_components({
				M.special_file_type_component(),
			}),
			" %t",
			"%#StatusLine#%=",
			concat_components({
				M.position_component(),
			}),
		})
	end

	local is_specical_file_type = vim.tbl_contains({
		"fugitive",
	}, vim.bo.filetype)

	local is_specical_buffer_type = vim.tbl_contains({
		"nofile",
		-- "nowrite",
		"terminal",
		"prompt",
	}, vim.bo.buftype)

	if is_specical_file_type or is_specical_buffer_type or vim.b.ft_as_statuline then
		return table.concat({
			concat_components({
				M.special_file_type_component(),
			}),
			"%#StatusLine#%=",
			concat_components({
				M.position_component(),
			}),
		})
	end

	return table.concat({
		concat_components({
			M.mode_component(),
			M.preview_window(),
			M.work_dir_component(),
			M.file_name_component(),
			M.git_component(),
		}),
		"%#StatusLine#%=",
		concat_components({
			M.dap_component() or "",
			M.diagnostics_component(),
			M.lsp_clients_component(),
			M.filetype_component(),
			M.encoding_component(),
			M.position_component(),
		}),
		" ",
	})
end

_G.nvim_statsline = M.render

vim.o.statusline = "%!v:lua.nvim_statsline()"
