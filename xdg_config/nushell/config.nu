# config.nu
#
# See https://www.nushell.sh/book/configuration.html
#
# This file is loaded after env.nu and before login.nu
#
# You can open this file in your default editor using:
# config nu
#
# See `help config nu` for more options

$env.config.show_banner = false

# $env.config.edit_mode = 'vi'
# $env.config.cursor_shape.vi_insert = 'line'
# $env.config.cursor_shape.vi_normal = 'block'

$env.PATH = $env.PATH | prepend ['~/.local/bin']
# XDG_***
# $env.XDG_CONFIG_HOME = $nu.home-path | path join '.config'
# $env.XDG_DATA_HOME = $nu.home-path | path join '.local' 'share'
# $env.XDG_STATE_HOME = $nu.home-path | path join '.local' 'state'
# $env.XDG_CACHE_HOME = $nu.home-path | path join '.cache'

mkdir ($nu.data-dir | path join "vendor/autoload")
# starship
## https://starship.rs/#nushell
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
# zoxide
zoxide init nushell | save -f ($nu.data-dir | path join "vendor/autoload/zoxide.nu")

alias e = nvim
alias cls = clear
