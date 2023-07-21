local wezterm = require("wezterm")
local act = wezterm.action

-- Events
wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

wezterm.on("update-right-status", function(window, pane)
	-- https://wezfurlong.org/wezterm/config/lua/window/set_right_status.html
	-- local hostname = " " .. wezterm.hostname() .. " "
	local date = wezterm.strftime("%Y-%m-%d %H:%M:%S")

	window:set_right_status(wezterm.format({
		-- { Text = hostname },
		{ Text = date },
	}))
end)

wezterm.on("toggle-leader", function(window, pane)
	local overrides = window:get_config_overrides() or {}
	if not overrides.leader then
		overrides.leader = { key = "f", mods = "CTRL" }
	else
		overrides.leader = nil
	end
	window:set_config_overrides(overrides)
end)

wezterm.on("toggle-tabbar", function(window, pane)
	local overrides = window:get_config_overrides() or {}
	if not overrides.enable_tab_bar then
		overrides.enable_tab_bar = true
	else
		overrides.enable_tab_bar = false
	end
	window:set_config_overrides(overrides)
end)

-- Config
local config = {
	check_for_updates = false,
	font_size = 13.0,
	-- https://wezfurlong.org/wezterm/config/fonts.html
	-- https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/FiraCode/Regular/complete
	-- font = wezterm.font("FiraCode NF"),
	line_height = 1.1,
	-- https://wezfurlong.org/wezterm/colorschemes/index.html
	color_scheme = "nord",
	colors = {
		scrollbar_thumb = "#4C566A",
		tab_bar = {
			active_tab = {
				bg_color = "#24283b",
				fg_color = "#c0caf5",
			},
		},
	},
	foreground_text_hsb = {
		hue = 1.0,
		saturation = 1.0,
		brightness = 1.2,
	},
	window_close_confirmation = "NeverPrompt",
	-- default_cursor_style = "BlinkingBar",
	-- cursor_blink_rate = 400,
	-- https://wezfurlong.org/wezterm/config/lua/config/window_decorations.html
	-- window_decorations = "NONE",
	enable_tab_bar = false,
	hide_tab_bar_if_only_one_tab = false,
	window_frame = {
		font_size = 10.0,
	},
	window_padding = {
		left = 1,
		right = 1,
		top = 0,
		bottom = 0,
	},
	enable_scroll_bar = false,
	disable_default_mouse_bindings = true,
	-- mouse_bindings = {
	-- 	{ event = { Down = { streak = 1, button = { WheelUp = 1 } } }, mods = "", action = act.ScrollByLine(-1) },
	-- 	{ event = { Down = { streak = 1, button = { WheelDown = 1 } } }, mods = "", action = act.ScrollByLine(1) },
	-- },
	disable_default_key_bindings = true,
	-- leader = { key = "f", mods = "CTRL" },
	keys = {
		-- toggle leader-key
		{ key = "f", mods = "CTRL|SHIFT", action = wezterm.action.EmitEvent("toggle-leader") },
		-- send CTRL-F key
		{ key = "f", mods = "LEADER|CTRL", action = wezterm.action.SendKey({ key = "f", mods = "CTRL" }) },
		-- toggle leader-tabbar
		{ key = "t", mods = "LEADER", action = wezterm.action.EmitEvent("toggle-tabbar") },
		-- show launcher
		-- { key = "l", mods = "LEADER|SHIFT", action = act.ShowLauncher },
		-- pane
		{ key = "-", mods = "LEADER", action = act({ SplitVertical = { domain = "CurrentPaneDomain" } }) },
		{ key = "|", mods = "LEADER|SHIFT", action = act({ SplitHorizontal = { domain = "CurrentPaneDomain" } }) },
		{ key = "x", mods = "LEADER", action = act({ CloseCurrentPane = { confirm = false } }) },
		{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
		{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
		{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
		{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
		{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
		{ key = "q", mods = "LEADER", action = act.PaneSelect({ alphabet = "", mode = "Activate" }) },
		-- tab
		{ key = "c", mods = "LEADER", action = act({ SpawnTab = "CurrentPaneDomain" }) },
		{ key = "n", mods = "LEADER|CTRL", action = act.ActivateTabRelative(-1) },
		{ key = "p", mods = "LEADER|CTRL", action = act.ActivateTabRelative(1) },
		{ key = "w", mods = "CMD", action = wezterm.action.CloseCurrentTab({ confirm = false }) },
		{ key = "x", mods = "LEADER|SHIFT", action = act({ CloseCurrentTab = { confirm = false } }) },
		{ key = "1", mods = "LEADER", action = act({ ActivateTab = 0 }) },
		{ key = "2", mods = "LEADER", action = act({ ActivateTab = 1 }) },
		{ key = "3", mods = "LEADER", action = act({ ActivateTab = 2 }) },
		{ key = "4", mods = "LEADER", action = act({ ActivateTab = 3 }) },
		{ key = "5", mods = "LEADER", action = act({ ActivateTab = 4 }) },
		{ key = "6", mods = "LEADER", action = act({ ActivateTab = 5 }) },
		{ key = "7", mods = "LEADER", action = act({ ActivateTab = 6 }) },
		{ key = "8", mods = "LEADER", action = act({ ActivateTab = 7 }) },
		{ key = "9", mods = "LEADER", action = act({ ActivateTab = 8 }) },
		-- scroll bar
		-- { key = "j", mods = "ALT", action = act.ScrollByLine(1) },
		-- { key = "k", mods = "ALT", action = act.ScrollByLine(-1) },
	},
	audible_bell = "Disabled",
}

config.ssh_domains = {
	{
		name = "bobx",
		remote_address = "127.0.0.1:6000",
		username = "liu",
	},
}

if wezterm.target_triple == "aarch64-apple-darwin" or wezterm.target_triple == "x86_64-apple-darwin" then
	local keys = {
		{ key = "q", mods = "CMD", action = wezterm.action.QuitApplication },
		{ key = "h", mods = "CMD", action = wezterm.action.HideApplication },
		-- copy, paste
		{ key = "x", mods = "CMD|SHIFT", action = act.ActivateCopyMode },
		{ key = "c", mods = "CMD|SHIFT", action = act.CopyTo("Clipboard") },
		{ key = "v", mods = "CMD|SHIFT", action = act.PasteFrom("Clipboard") },
	}
	for _, key in ipairs(keys) do
		table.insert(config.keys, key)
	end
end

if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	config.default_prog = { "wsl.exe", "--cd", "~" }
	config.font = wezterm.font("FiraCode NF")

	local keys = {
		{ key = "Enter", mods = "ALT", action = "ToggleFullScreen" },
		{ key = "Insert", mods = "SHIFT", action = act.PasteFrom("Clipboard") },
		{ key = "x", mods = "ALT|SHIFT", action = act.ActivateCopyMode },
		{ key = "c", mods = "ALT|SHIFT", action = act.CopyTo("Clipboard") },
		{ key = "v", mods = "ALT|SHIFT", action = act.PasteFrom("Clipboard") },
	}
	for _, key in ipairs(keys) do
		table.insert(config.keys, key)
	end

	local function wsl_domains()
		local wsl_domains = wezterm.default_wsl_domains()
		for idx, dom in ipairs(wsl_domains) do
			dom.default_cwd = "~"
		end

		return wsl_domains
	end
	config.wsl_domains = wsl_domains()
end
return config
