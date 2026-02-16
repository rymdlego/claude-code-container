IMAGE   := claude-code
LANG    ?= go
PREFIX  := $(HOME)/.local/bin
SYMLINK := $(PREFIX)/ccc
RUNTIME := $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)

DOCKERFILE_go   := Dockerfile
DOCKERFILE_rust := Dockerfile.rust
DOCKERFILE      := $(DOCKERFILE_$(LANG))

.PHONY: build rebuild install uninstall

build:
	$(RUNTIME) build -f $(DOCKERFILE) -t $(IMAGE) .

rebuild:
	$(RUNTIME) build -f $(DOCKERFILE) --no-cache -t $(IMAGE) .

install: build
	mkdir -p $(PREFIX)
	ln -sf $(abspath claude-run.sh) $(SYMLINK)

uninstall:
	rm -f $(SYMLINK)
