# Claude Code Container

Containerized [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Includes Go tooling by default, but the Dockerfile can be adapted to any language or toolchain.

## Prerequisites

- Docker or Podman

## Quick start

```bash
make build
./claude-run.sh
```

Or install as `ccc` on your PATH:

```bash
make install         # builds image and symlinks ccc -> ~/.local/bin/ccc
ccc                 # run from any project directory
```

### Make targets

| Target | Description |
|---|---|
| `make build` | Build the container image |
| `make rebuild` | Build from scratch (no cache) |
| `make install` | Build + symlink `ccc` to `~/.local/bin` |
| `make uninstall` | Remove the `ccc` symlink |

## Usage

```bash
ccc                    # new session
ccc --continue         # resume last session
ccc --resume           # pick a session to resume
ccc -p "explain this"  # non-interactive
```

## Volume mounts

Only the working directory is required. The others are mounted if present on the host.

| Host path | Container path | Purpose | Required |
|---|---|---|---|
| Current directory | `/work` | Working directory | Yes |
| `~/.claude` | `/home/claude/.claude` | Session history, memory, settings | No |
| `~/.claude.json` | `/config/claude.json` | Auth config (read-only) | No |
| `~/.gitconfig` | `/home/claude/.gitconfig` | Git config (read-only) | No |

## Environment variables

`ANTHROPIC_*` and `CLAUDE_*` env vars are forwarded from the host into the container automatically.

## Permissions

Claude Code runs with full permissions inside the container, so it operates uninterrupted without permission prompts while remaining in a safe, containerized environment.
