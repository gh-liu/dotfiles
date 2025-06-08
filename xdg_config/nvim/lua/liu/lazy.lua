-- download lazy.nvim {{{1
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})

	local name = [[lazy]]
	if vim.v.shell_error == 0 then
		vim.cmd([[redraw]])
		print(name .. ": finished installing")
	else
		print(name .. ": fail to install")
	end
end
vim.opt.rtp:prepend(lazypath)
-- }}}

local config = require("liu.user_config")

-- lazy.nvim setup {{{1
require("lazy").setup(
	{ import = "liu.plugins" },
	-- https://lazy.folke.io/configuration
	{
		dev = {
			---@type string | fun(plugin: LazyPlugin): string directory where you store your local plugin projects
			path = "~/dev/vim",
			---@type string[] plugins that match these patterns will use your local versions instead of being fetched from GitHub
			patterns = {},
			fallback = true, -- Fallback to git when local plugin doesn't exist
		},
		performance = {
			rtp = {
				---@type string[]
				paths = {}, -- add any custom paths here that you want to includes in the rtp
				---@type string[] list any plugins you want to disable here
				disabled_plugins = {
					"gzip",
					-- "matchit",
					-- "matchparen",
					"netrwPlugin",
					"tarPlugin",
					"tohtml",
					"tutor",
					"zipPlugin",
				},
			},
		},
		checker = {
			enabled = false,
			notify = true,
		},
		change_detection = {
			enabled = false,
			notify = false,
		},
		ui = {
			backdrop = 99, -- 0-100
			border = config.borders or "none",
			custom_keys = {
				["<localleader>l"] = false,
				["<localleader>t"] = false,
				["<localleader>i"] = false,
				["gx"] = {
					---@param plug LazyPlugin
					function(plug)
						vim.ui.open(plug.url:gsub("%.git$", ""))
					end,
					desc = "Plugin repo",
				},
				["gi"] = {
					---@param plug LazyPlugin
					function(plug)
						local url = plug.url:gsub("%.git$", "")
						local line = vim.api.nvim_get_current_line()
						local issue = line:match("#(%d+)")
						local commit = line:match(("%x"):rep(6) .. "+")
						if issue then
							vim.ui.open(url .. "/issues/" .. issue)
						elseif commit then
							vim.ui.open(url .. "/commit/" .. commit)
						end
					end,
					desc = "Open issue/commit",
				},
			},
		},
	}
)
-- }}}

-- lazy patch {{{1
local config_path = vim.fn.stdpath("config") --[[@as string]]

local package_path

---Print git command error
---@param cmd string[] shell command
---@param msg string error message
---@param lev number? log level to use for errors, defaults to WARN
---@return nil
local function log_error(cmd, msg, lev)
	lev = lev or vim.log.levels.WARN
	vim.notify("[git] failed to execute git command: " .. table.concat(cmd, " ") .. "\n" .. msg, lev)
end

---Execute git command in given directory synchronously
---@param path string
---@param cmd string[] git command to execute
---@param error_lev number? log level to use for errors, hide errors if nil or false
---@reurn { success: boolean, output: string }
local function dir_execute_git_cmd(path, cmd, error_lev)
	local shell_args = { "git", "-C", path, unpack(cmd) }
	local shell_out = vim.fn.system(shell_args)
	if vim.v.shell_error ~= 0 then
		if error_lev then
			log_error(shell_args, shell_out, error_lev)
		end
		return {
			success = false,
			output = shell_out,
		}
	end
	return {
		success = true,
		output = shell_out,
	}
end

-- Reverse/Apply local patches on updating/installing plugins,
-- must be created before setting lazy to apply the patches properly
vim.api.nvim_create_autocmd("User", {
	desc = "Reverse/Apply local patches on updating/intalling plugins.",
	group = vim.api.nvim_create_augroup("LazyPatches", {}),
	pattern = {
		"LazyInstall*",
		"LazyUpdate*",
		"LazySync*",
		"LazyRestore*",
	},
	callback = function(info)
		-- In a lazy sync action:
		-- -> LazySyncPre     <- restore packages
		-- -> LazyInstallPre
		-- -> LazyUpdatePre
		-- -> LazyInstall
		-- -> LazyUpdate
		-- -> LazySync        <- apply patches
		vim.g._lz_syncing = vim.g._lz_syncing or info.match == "LazySyncPre"
		if vim.g._lz_syncing and not info.match:find("^LazySync") then
			return
		end
		if info.match == "LazySync" then
			vim.g._lz_syncing = nil
		end

		if not package_path then
			package_path = require("lazy.core.config").options.root
		end

		local patches_path = vim.fs.joinpath(config_path, "patches")
		for patch in vim.fs.dir(patches_path) do
			local patch_path = vim.fs.joinpath(patches_path, patch)
			local plugin_path = vim.fs.joinpath(package_path, (patch:gsub("%.patch$", "")))
			if vim.uv.fs_stat(plugin_path) then
				dir_execute_git_cmd(plugin_path, {
					"restore",
					".",
				})
				if not info.match:find("Pre$") then
					vim.notify("[packages] applying patch " .. patch)
					dir_execute_git_cmd(plugin_path, {
						"apply",
						"--ignore-space-change",
						patch_path,
					}, vim.log.levels.WARN)
				end
			end
		end
	end,
})

vim.api.nvim_create_user_command("LazyPatch", function(args)
	local plugin_name = args.fargs[1]

	local plugins = require("lazy.core.config").plugins
	local plugin = plugins[plugin_name]

	local diff_cmd = { "diff" }
	local cmd = { "git", "-C", plugin.dir, unpack(diff_cmd) }
	local obj = vim.system(cmd, {}):wait()
	if obj.code == 0 then
		local patches_dir = vim.fn.stdpath("config") .. "/patches"
		local f = io.open(patches_dir .. "/" .. plugin_name .. ".patch", "w")
		f:write(obj.stdout)
		io.close(f)
	else
		vim.api.nvim_echo({ { obj.stderr } }, true, { err = true })
	end
end, {
	complete = function()
		local plugins = require("lazy.core.config").plugins
		return vim.tbl_keys(plugins)
	end,
	nargs = 1,
})
-- }}}

-- vim: foldmethod=marker
