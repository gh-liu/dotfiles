FROM docker.io/library/golang:1.24.1 AS build
WORKDIR /
COPY . .
ENV GO111MODULE=on
ENV GOPROXY=https://goproxy.cn
RUN CGO_ENABLED=0 go install github.com/go-delve/delve/cmd/dlv@latest
RUN CGO_ENABLED=0 go build -gcflags "all=-N -l" -o app
RUN chmod +x app
# RUN which dlv

FROM scratch
COPY --from=build /go/bin/dlv /dlv
COPY --from=build /app /app

ENTRYPOINT [ "/dlv", "exec", "app", "--headless", "--listen=:5678", "--accept-multiclient", "--continue" ]
# ENTRYPOINT [ "/app" ]
