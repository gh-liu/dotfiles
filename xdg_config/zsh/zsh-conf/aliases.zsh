alias .='cd .'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias cls=clear

alias ll='ls -Falh'
# alias ls='ls -F --color=auto --group-directories-first --sort=version'

alias mkdir='mkdir -v'
alias mv='mv -v'
alias cp='cp -v'
alias rm='rm -v'
alias ln='ln -v'

alias now='date +%s'

which exa &>/dev/null && alias ls="exa"
which bat &>/dev/null && alias cat="bat --theme=\"Nord\" --style=\"changes\""
which batcat &>/dev/null && alias cat="batcat --theme=\"Nord\" --style=\"changes\""
which fdfind &>/dev/null && alias fd="fdfind"


if [[ $LinuxDistro == Ubuntu ]]; then
	alias sai='sudo apt install '
	alias sau="sudo apt update -y && sudo apt upgrade -y"
fi

alias e=nvim
alias codei=code-insiders

alias pc=proxychains4
alias pm=podman
alias lzg=lazygit
alias lzd=lazydocker
alias hugos="hugo server -D --bind="0.0.0.0" --baseURL=http://$HOSTIP:1313"
