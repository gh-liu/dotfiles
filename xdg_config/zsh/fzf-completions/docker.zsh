# fzf completion for docker
_fzf_complete_docker() {
	local tokens=(${(z)LBUFFER})
	local cmd=${tokens[2]-}

	case "$cmd" in
	create|history|run)
		_fzf_complete --ansi --header-lines=1 -- "$@" < <(docker images --format 'table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}' 2>/dev/null)
		;;
	push)
		_fzf_complete --ansi --header-lines=1 -- "$@" < <(docker images --filter 'dangling=false' --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' 2>/dev/null)
		;;
	rmi|save|tag)
		_fzf_complete --ansi --header-lines=1 -m -- "$@" < <(docker images --format 'table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.Size}}' 2>/dev/null)
		;;
	attach|exec|top)
		_fzf_complete --ansi --header-lines=1 -- "$@" < <(docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}' 2>/dev/null)
		;;
	kill|pause|stop|unpause)
		_fzf_complete --ansi --header-lines=1 -m -- "$@" < <(docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}' 2>/dev/null)
		;;
	commit|diff|export|logs|port|rename)
		_fzf_complete --ansi --header-lines=1 -- "$@" < <(docker ps -a --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}' 2>/dev/null)
		;;
	restart|rm|start|stats|update|wait)
		_fzf_complete --ansi --header-lines=1 -m -- "$@" < <(docker ps -a --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}' 2>/dev/null)
		;;
	esac
}

_fzf_complete_docker_post() {
	awk '{ print $1 }'
}
