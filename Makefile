gotools:
	# go dev
	go install github.com/klauspost/asmfmt/cmd/asmfmt@latest
	go install github.com/go-delve/delve/cmd/dlv@latest
	go install github.com/kisielk/errcheck@latest
	go install github.com/davidrjenni/reftools/cmd/fillstruct@latest
	go install github.com/rogpeppe/godef@latest
	go install golang.org/x/tools/cmd/goimports@latest
	go install golang.org/x/lint/golint@latest
	go install github.com/mgechev/revive@latest
	go install golang.org/x/tools/gopls@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install honnef.co/go/tools/cmd/staticcheck@latest
	go install github.com/fatih/gomodifytags@latest
	go install golang.org/x/tools/cmd/gorename@latest
	go install github.com/jstemmer/gotags@latest
	go install golang.org/x/tools/cmd/guru@latest
	go install github.com/josharian/impl@latest
	go install honnef.co/go/tools/cmd/keyify@latest
	go install github.com/fatih/motion@latest
	go install github.com/koron/iferr@latest
	# protobuf
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	# bench
	go install golang.org/x/perf/cmd/benchstat@latest
	go install github.com/aclements/perflock/cmd/perflock@latest