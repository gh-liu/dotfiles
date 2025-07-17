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

mkdir ($nu.data-dir | path join "vendor/autoload")
# starship
## https://starship.rs/#nushell
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")
# zoxide
zoxide init nushell | save -f ($nu.data-dir | path join "vendor/autoload/zoxide.nu")

alias e = nvim
alias cls = clear
