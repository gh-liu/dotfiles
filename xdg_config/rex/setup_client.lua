-- Apply with `rex do setup_client` or `rex do ~/.config/rex/setup_client.lua`.
-- Commented entries document the current defaults; uncomment to pin a value.
-- Explicit values make repeated runs idempotent. Omitted entries are not reset.
-- Enum argument casts enable value completion in EmmyLua LS.
--
-- Import Nord and Nord Light on a new machine before selecting them here:
-- rex do client.theme.import path='/Applications/Ghostty.app/Contents/Resources/ghostty/themes/Nord'
-- rex do client.theme.import path='/Applications/Ghostty.app/Contents/Resources/ghostty/themes/Nord Light'
local function setup_client()
        -- Notifications
        rex.client.queue(
                "client.setting.notifications.overview.position",
                { value = "bottom_right" } --[[@as RexClientSettingNotificationsOverviewPositionActionArgs]]
        )
        -- rex.client.queue("client.setting.notifications.activity.tab_activity", { value = true })
        -- rex.client.queue("client.setting.notifications.activity.idle_in_activity", { value = true })
        -- rex.client.queue("client.setting.notifications.activity.system_notifications", { value = true })
        -- rex.client.queue("client.setting.notifications.activity.dock_badge", { value = true })
        rex.client.queue("client.setting.notifications.activity.sounds", { value = false })
        -- rex.client.queue("client.setting.notifications.activity.sound_volume", { value = 2 })
        rex.client.queue(
                "client.setting.notifications.activity.status_working",
                {
                        value = true,
                        tabs = true,
                        notifications = false,
                        dock_badge = false,
                        sound = false,
                        sound_name = "loading"
                } --[[@as RexClientSettingNotificationsActivityStatusWorkingActionArgs]]
        )
        -- rex.client.queue("client.setting.notifications.activity.status_blocked", {
        --         value = true, tabs = true, notifications = true, dock_badge = true,
        --         sound = true, sound_name = "attention"
        -- } --[[@as RexClientSettingNotificationsActivityStatusBlockedActionArgs]])
        -- rex.client.queue("client.setting.notifications.activity.status_error", {
        --         value = true, tabs = true, notifications = true, dock_badge = true,
        --         sound = true, sound_name = "error"
        -- } --[[@as RexClientSettingNotificationsActivityStatusErrorActionArgs]])
        -- rex.client.queue("client.setting.notifications.activity.status_done", {
        --         value = true, tabs = true, notifications = true, dock_badge = true,
        --         sound = true, sound_name = "success"
        -- } --[[@as RexClientSettingNotificationsActivityStatusDoneActionArgs]])
        -- rex.client.queue("client.setting.notifications.macos.terminal_notifications", { value = true })

        -- Interface: style and tint share state; set style before tint.
        rex.client.queue(
                "client.setting.interface.appearance.scheme",
                { value = "dark" } --[[@as RexClientSettingInterfaceAppearanceSchemeActionArgs]]
        )
        rex.client.queue(
                "client.setting.interface.appearance.style",
                { value = "classic" } --[[@as RexClientSettingInterfaceAppearanceStyleActionArgs]]
        )
        rex.client.queue("client.setting.interface.appearance.tint", { value = true })
        -- rex.client.queue("client.setting.interface.appearance.glass", { value = false })
        rex.client.queue(
                "client.setting.interface.toolbar.layout",
                { value = "left" } --[[@as RexClientSettingInterfaceToolbarLayoutActionArgs]]
        )
        -- rex.client.queue("client.setting.interface.toolbar.auto_hide_toolbar", { value = "always_show" } --[[@as RexClientSettingInterfaceToolbarAutoHideToolbarActionArgs]])
        -- rex.client.queue("client.setting.interface.tab_behavior.fill", { value = false })
        rex.client.queue(
                "client.setting.interface.tabs.color",
                { value = "active_panes" } --[[@as RexClientSettingInterfaceTabsColorActionArgs]]
        )
        rex.client.queue(
                "client.setting.interface.tabs.shell_icon_theme",
                { value = "default" } --[[@as RexClientSettingInterfaceTabsShellIconThemeActionArgs]]
        )
        rex.client.queue("client.setting.interface.tabs.count", { value = 3 })
        rex.client.queue(
                "client.setting.interface.panes.density",
                { value = "compact" } --[[@as RexClientSettingInterfacePanesDensityActionArgs]]
        )
        rex.client.queue(
                "client.setting.interface.panes.headers",
                { value = "always_show" } --[[@as RexClientSettingInterfacePanesHeadersActionArgs]]
        )
        -- rex.client.queue("client.setting.interface.window.sidebar_text_size", { value = 13 })
        -- rex.client.queue("client.setting.interface.window.window_width", { value = true })
        rex.client.queue(
                "client.setting.interface.window.sidebar_swipe",
                { value = "swipe" } --[[@as RexClientSettingInterfaceWindowSidebarSwipeActionArgs]]
        )
        -- rex.client.queue("client.setting.interface.pane_padding.horizontal", { value = 10 })
        rex.client.queue("client.setting.interface.pane_padding.vertical", { value = 6 })
        -- rex.client.queue("client.setting.interface.pane_padding.color", { value = "automatic" } --[[@as RexClientSettingInterfacePanePaddingColorActionArgs]])
        rex.client.queue("client.setting.interface.pane_padding.program_background", { value = false })
        -- rex.client.queue("client.setting.interface.active_panes.active_border", { value = false })
        -- rex.client.queue("client.setting.interface.active_panes.active_border_color", { value = "accent" } --[[@as RexClientSettingInterfaceActivePanesActiveBorderColorActionArgs]])
        -- rex.client.queue("client.setting.interface.active_panes.active_border_opacity", { value = 0.9 })
        -- rex.client.queue("client.setting.interface.active_panes.active_border_animation", { value = "fade" } --[[@as RexClientSettingInterfaceActivePanesActiveBorderAnimationActionArgs]])
        rex.client.queue(
                "client.setting.interface.active_panes.fade",
                { value = "both" } --[[@as RexClientSettingInterfaceActivePanesFadeActionArgs]]
        )
        rex.client.queue("client.setting.interface.active_panes.inactive_window", { value = true })
        -- rex.client.queue("client.setting.interface.splits_focus.autobalance", { value = true })
        -- rex.client.queue("client.setting.interface.splits_focus.focus_follows_mouse", { value = false })
        -- rex.client.queue("client.setting.interface.gestures.use_gestures", { value = true })
        -- rex.client.queue("client.setting.interface.animation.style", { value = "snappy" } --[[@as RexClientSettingInterfaceAnimationStyleActionArgs]])
        -- rex.client.queue("client.setting.interface.app_icon.selection", { value = "default" } --[[@as RexClientSettingInterfaceAppIconSelectionActionArgs]])
        -- rex.client.queue("client.setting.interface.app_icon.show_app_icon", { value = "dock_and_menu_bar" } --[[@as RexClientSettingInterfaceAppIconShowAppIconActionArgs]])
        rex.client.queue("client.setting.interface.launch.show_window", { value = true })

        -- Themes: names work across machines; custom theme IDs do not.
        rex.client.queue("client.setting.themes.light.palette", { value = "Nord Light" })
        -- rex.client.queue("client.setting.themes.light.extended_palette", { value = true })
        rex.client.queue("client.setting.themes.dark.palette", { value = "Nord" })
        rex.client.queue("client.setting.themes.dark.extended_palette", { value = true })

        -- Terminal
        rex.client.queue("client.setting.terminal.typography.font", { value = "Menlo" })
        rex.client.queue("client.setting.terminal.typography.size", { value = 15 })
        -- rex.client.queue("client.setting.terminal.typography.style", { value = "Regular" })
        -- rex.client.queue("client.setting.terminal.typography.line_height", { value = 0 })
        -- rex.client.queue("client.setting.terminal.advanced_fonts.character_spacing", { value = "0" })
        -- rex.client.queue("client.setting.terminal.advanced_fonts.ligatures", { value = true })
        -- rex.client.queue("client.setting.terminal.advanced_fonts.bold_italic", { value = "both" } --[[@as RexClientSettingTerminalAdvancedFontsBoldItalicActionArgs]])
        -- rex.client.queue("client.setting.terminal.advanced_fonts.synthesize", { value = true })
        -- rex.client.queue("client.setting.terminal.advanced_fonts.smoothing", { value = false })
        -- rex.client.queue("client.setting.terminal.advanced_fonts.fallback_fonts", { value = "" })
        -- rex.client.queue("client.setting.terminal.colors.contrast", { value = true })
        -- rex.client.queue("client.setting.terminal.colors.palette", { value = false })
        -- rex.client.queue("client.setting.terminal.colors.display_p3", { value = false })
        -- Setting interval enables custom mode; restore the preset afterwards.
        rex.client.queue("client.setting.terminal.cursor.interval", { value = 750 })
        rex.client.queue(
                "client.setting.terminal.cursor.blink",
                { value = "slow" } --[[@as RexClientSettingTerminalCursorBlinkActionArgs]]
        )
        rex.client.queue(
                "client.setting.terminal.cursor.style",
                { value = "bar" } --[[@as RexClientSettingTerminalCursorStyleActionArgs]]
        )
        -- rex.client.queue("client.setting.terminal.cursor.force", { value = false })
        -- rex.client.queue("client.setting.terminal.cursor.shaders", { value = false })
        -- rex.client.queue("client.setting.terminal.cursor.shader", { value = "warp" } --[[@as RexClientSettingTerminalCursorShaderActionArgs]])
        -- rex.client.queue("client.setting.terminal.keyboard.sequence_hints", { value = true })
        rex.client.queue(
                "client.setting.terminal.keyboard.option",
                { value = "left_sends_alt" } --[[@as RexClientSettingTerminalKeyboardOptionActionArgs]]
        )
        rex.client.queue("client.setting.terminal.scrolling.smooth", { value = true })
        -- rex.client.queue("client.setting.terminal.resizing.smooth", { value = true })
        -- rex.client.queue("client.setting.terminal.selection.copy_on_select", { value = false })
        -- rex.client.queue("client.setting.terminal.selection.play_animation_on_copy", { value = true })
        -- rex.client.queue("client.setting.terminal.selection.foreground", { value = "theme" } --[[@as RexClientSettingTerminalSelectionForegroundActionArgs]])
        -- rex.client.queue("client.setting.terminal.selection.background", { value = "theme" } --[[@as RexClientSettingTerminalSelectionBackgroundActionArgs]])
        -- rex.client.queue("client.setting.terminal.selection.corners", { value = true })
        -- rex.client.queue("client.setting.terminal.links.custom_schemes", { value = "ask" } --[[@as RexClientSettingTerminalLinksCustomSchemesActionArgs]])
        -- rex.client.queue("client.setting.terminal.path_browser.recent_paths", { value = true })
        -- rex.client.queue("client.setting.terminal.titles.prefer_generated", { value = true })
        -- rex.client.queue("client.setting.terminal.shell.command", { value = "" })

        -- Remote hosts and developer settings
        -- rex.client.queue("client.setting.remote_hosts.ssh.agent", { value = "system" } --[[@as RexClientSettingRemoteHostsSshAgentActionArgs]])
        -- rex.client.queue("client.setting.remote_hosts.ssh.custom_path", { value = "" })
        rex.client.queue("client.setting.developer.mode.enabled", { value = true })
        -- rex.client.queue("client.setting.developer.experimental.terminal_anchor", { value = "top" } --[[@as RexClientSettingDeveloperExperimentalTerminalAnchorActionArgs]])
        -- rex.client.queue("client.setting.developer.experimental.new_quick_switcher", { value = false })
end

-- require passes the module name. A standalone Rex script receives no varargs.
if ... == "setup_client" then
        return setup_client
end
setup_client()
