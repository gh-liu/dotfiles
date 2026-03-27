# fzf completion for aws s3

_aws_s3_fzf_list_buckets() {
	local bucket_prefix=${1#s3://}

	aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null |
		tr '\t' '\n' |
		awk -v bucket_prefix="$bucket_prefix" '
			NF {
				if (bucket_prefix == "" || index($1, bucket_prefix) == 1) {
					print "s3://" $1 "/\tbucket"
				}
			}
		'
}

_aws_s3_fzf_list_objects() {
	local current=$1
	local remainder=${current#s3://}
	local bucket=${remainder%%/*}
	local key_prefix=${remainder#*/}
	local parent_prefix=""
	local name_prefix=""
	local list_uri

	[[ -n "$bucket" && "$remainder" != "$bucket" ]] || return 0

	if [[ "$key_prefix" == */ ]]; then
		parent_prefix=$key_prefix
	elif [[ "$key_prefix" == */* ]]; then
		parent_prefix="${key_prefix%/*}/"
		name_prefix="${key_prefix##*/}"
	else
		name_prefix=$key_prefix
	fi

	list_uri="s3://$bucket/${parent_prefix}"

	aws s3 ls "$list_uri" 2>/dev/null |
		awk -v bucket="$bucket" -v parent_prefix="$parent_prefix" -v name_prefix="$name_prefix" '
			/^[[:space:]]*PRE[[:space:]]+/ {
				entry = $0
				sub(/^[[:space:]]*PRE[[:space:]]+/, "", entry)
				if (name_prefix == "" || index(entry, name_prefix) == 1) {
					print "s3://" bucket "/" parent_prefix entry "\tprefix"
				}
				next
			}
			NF {
				entry = $0
				sub(/^[0-9-]+[[:space:]][0-9:]+[[:space:]]+[0-9]+[[:space:]]+/, "", entry)
				if (entry != "" && (name_prefix == "" || index(entry, name_prefix) == 1)) {
					print "s3://" bucket "/" parent_prefix entry "\tobject"
				}
			}
		'
}

_aws_s3_fzf_candidates() {
	local current=$1

	if [[ -z "$current" || "$current" == s3://* && "$current" != s3://*/* ]]; then
		_aws_s3_fzf_list_buckets "$current"
	else
		_aws_s3_fzf_list_objects "$current"
	fi
}

_fzf_complete_aws() {
	(( $+commands[aws] )) || return

	local lbuf=${1-}
	local tokens=(${(z)LBUFFER})
	local prev_tokens=(${(z)lbuf})
	local cmd=${tokens[2]-}
	local sub=${tokens[3]-}
	local current=${prefix:-}
	local -a prev_positionals
	local token
	local i

	[[ "$cmd" == "s3" ]] || return

	case "$sub" in
	ls|mb|presign|rb|rm)
		if [[ -n "$current" && "$current" != s3://* ]]; then
			_fzf_path_completion "$current" "$@"
			return
		fi

		_fzf_complete --with-nth=1 --delimiter='\t' -- "$@" < <(_aws_s3_fzf_candidates "$current")
		;;
	cp|mv|sync)
		for ((i = 4; i <= ${#prev_tokens[@]}; i++)); do
			token=${prev_tokens[i]}
			[[ "$token" == --* ]] && continue
			prev_positionals+=("$token")
		done

		if [[ "$current" == s3://* ]]; then
			_fzf_complete --with-nth=1 --delimiter='\t' -- "$@" < <(_aws_s3_fzf_candidates "$current")
		elif ((${#prev_positionals[@]} >= 1)) && [[ "${prev_positionals[1]}" != s3://* ]]; then
			_fzf_complete --with-nth=1 --delimiter='\t' -- "$@" < <(_aws_s3_fzf_candidates "$current")
		else
			_fzf_path_completion "$current" "$@"
		fi
		;;
	esac
}

_fzf_complete_aws_post() {
	cut -f1
}
