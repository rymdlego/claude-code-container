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

# Mount volumes that exist on the host
VOL_ARGS=(-v "$(pwd)":/work)
[ -d ~/.claude ]     && VOL_ARGS+=(-v ~/.claude:/home/claude/.claude)
[ -f ~/.claude.json ] && VOL_ARGS+=(-v ~/.claude.json:/config/claude.json:ro)
[ -f ~/.gitconfig ]  && VOL_ARGS+=(-v ~/.gitconfig:/home/claude/.gitconfig:ro)

$RUNTIME run -it --rm \
    ${ENV_ARGS[@]+"${ENV_ARGS[@]}"} \
    "${VOL_ARGS[@]}" \
    claude-code "${CLAUDE_ARGS[@]}"
