IMAGE   := claude-code
PREFIX  := $(HOME)/.local/bin
SYMLINK := $(PREFIX)/ccc
RUNTIME := $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null)

.PHONY: build rebuild install uninstall

build:
	$(RUNTIME) build -t $(IMAGE) .

rebuild:
	$(RUNTIME) build --no-cache -t $(IMAGE) .

install: build
	mkdir -p $(PREFIX)
	ln -sf $(abspath claude-run.sh) $(SYMLINK)

uninstall:
	rm -f $(SYMLINK)
