#!/bin/bash
set -euo pipefail

# Pick container runtime: prefer podman, fall back to docker
if command -v podman &>/dev/null; then
    RUNTIME=podman
elif command -v docker &>/dev/null; then
    RUNTIME=docker
else
    echo "Error: neither podman nor docker is installed" >&2
    exit 1
fi

CLAUDE_ARGS=("claude")
if [ $# -gt 0 ]; then
    CLAUDE_ARGS+=("$@")
fi

# Forward ANTHROPIC_* and CLAUDE_* env vars into the container
ENV_ARGS=()
while IFS='=' read -r name _; do
    ENV_ARGS+=(-e "$name")
done < <(env | grep -E '^(ANTHROPIC|CLAUDE)_' || true)

# On macOS, Claude Code stores OAuth credentials in the Keychain rather than
# in a file.  The Linux container expects ~/.claude/.credentials.json, so we
# always extract a fresh token from the Keychain (the container may write an
# empty or stale credentials file to the mounted ~/.claude directory).
CREDS_TMPFILE=""
if [ "$(uname)" = "Darwin" ]; then
    creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null) || true
    if [ -n "$creds" ]; then
        CREDS_TMPFILE=$(mktemp)
        printf '%s' "$creds" > "$CREDS_TMPFILE"
        trap 'rm -f "$CREDS_TMPFILE"' EXIT
    fi
fi

# Mount volumes that exist on the host
VOL_ARGS=(-v "$(pwd)":/work)
[ -d ~/.claude ]     && VOL_ARGS+=(-v ~/.claude:/home/claude/.claude)
[ -f ~/.claude.json ] && VOL_ARGS+=(-v ~/.claude.json:/config/claude.json:ro)

# Mount extracted credentials file into the container
if [ -n "$CREDS_TMPFILE" ]; then
    VOL_ARGS+=(-v "$CREDS_TMPFILE:/home/claude/.claude/.credentials.json:ro")
fi
[ -f ~/.gitconfig ]  && VOL_ARGS+=(-v ~/.gitconfig:/home/claude/.gitconfig:ro)

# Resolve symlinks in ~/.claude that point outside the directory so they
# remain valid inside the container.  Each external target is bind-mounted
# at the same path relative to /home/claude.
if [ -d ~/.claude ]; then
    for link in ~/.claude/*; do
        [ -L "$link" ] || continue
        target=$(readlink -f "$link" 2>/dev/null) || continue
        case "$target" in "$HOME"/.claude/*) continue;; esac   # already inside
        rel="${target#"$HOME"/}"
        VOL_ARGS+=(-v "$target:/home/claude/$rel:ro")
    done
fi

$RUNTIME run -it --rm \
    ${ENV_ARGS[@]+"${ENV_ARGS[@]}"} \
    "${VOL_ARGS[@]}" \
    claude-code "${CLAUDE_ARGS[@]}"
