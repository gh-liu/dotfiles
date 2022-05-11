local wezterm = require("wezterm")

return {
  font_size = 12.0,
  -- default_prog = { "ssh", "130" },
  -- https://wezfurlong.org/wezterm/config/fonts.html
  font = wezterm.font("JetBrainsMonoNL NF"),
  -- https://wezfurlong.org/wezterm/colorschemes/index.html
  color_scheme = "GitHub Dark",
  colors = {
    tab_bar = {
      active_tab = {
        bg_color = "#24283b",
        fg_color = "#c0caf5",
      },
    },
  },
  window_frame = {
    font_size = 12.0,
  },
  window_padding = {
    left = 5,
    right = 5,
    top = 0,
    bottom = 0,
  },
  foreground_text_hsb = {
    hue = 1.0,
    saturation = 1.0,
    brightness = 1.2,
  },
  keys = {
    { key = "f", mods = "SHIFT|CTRL", action = "ToggleFullScreen" },
  },
}
