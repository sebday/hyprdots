GO ?= $(shell command -v go 2>/dev/null || echo mise exec go -- go)

.PHONY: build clean
build:
	CGO_ENABLED=0 $(GO) build -trimpath -ldflags='-s -w' -o bin/steam-status ./cmd/steam-status

clean:
	rm -f bin/steam-status
