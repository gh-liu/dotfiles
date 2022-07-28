# golang
alias fmtf='gofumpt -l -w . && go mod tidy'
alias fmts='gosimports -w . && go mod tidy'

alias gotc='go tool compile -S -N -l'
alias gobs='go build -gcflags -S'

function goasm() {
  go build -gcflags=-S $@ 2>&1 | grep -v PCDATA | grep -v FUNCDATA | less
}

function gocover() {
  local t=$(mktemp -t)
  go test $COVERFLAGS -coverprofile=$t $@ &&
    go tool cover -func=$t &&
    unlink $t
}
