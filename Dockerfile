FROM ubuntu:24.04

ARG TARGETARCH

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    curl git make gosu jq ca-certificates \
    build-essential pkg-config libssl-dev \
    python3 python3-pip python3-venv && \
    GO_ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL https://go.dev/dl/go1.25.7.linux-${GO_ARCH}.tar.gz \
    | tar -xz -C /usr/local && \
    curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
    | sh -s -- -b /usr/local/bin

RUN useradd -m -s /bin/bash claude
USER claude

# Install Rust via rustup + Python dev tools
RUN --mount=type=cache,target=/home/claude/.cargo/registry,uid=1000,gid=1000 \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . "$HOME/.cargo/env" && rustup component add rust-analyzer && \
    rm -rf "$HOME/.rustup/tmp" "$HOME/.rustup/downloads" && \
    python3 -m pip install --user --no-cache-dir --break-system-packages \
    ruff mypy pytest

ENV PATH="/home/claude/.local/bin:/home/claude/.cargo/bin:/usr/local/go/bin:${PATH}"

# Cache-bust only the Claude Code install: make update-claude
ARG CLAUDE_BUST_CACHE=0
RUN curl -fsSL https://claude.ai/install.sh | bash

USER root

# Pre-approve all tool permissions via managed settings (does not touch user settings.json)
RUN mkdir -p /etc/claude-code && \
    printf '{"permissions":{"allow":["Bash(*)","Edit","Write","WebFetch","WebSearch","NotebookEdit"]}}\n' \
    > /etc/claude-code/managed-settings.json

RUN printf '#!/bin/bash\n\
chown -R claude:claude /home/claude/.claude 2>/dev/null\n\
chown claude:claude /work 2>/dev/null\n\
cfg=/home/claude/.claude.json\n\
src=/config/claude.json\n\
# Copy config in (bind-mounting files directly breaks on atomic writes)\n\
if [ -f "$src" ]; then\n\
    cp "$src" "$cfg"\n\
else\n\
    [ -f "$cfg" ] || echo "{}" > "$cfg"\n\
fi\n\
jq ".hasCompletedOnboarding = true | .projects[\"/work\"].hasTrustDialogAccepted = true" "$cfg" > "${cfg}.tmp" && mv "${cfg}.tmp" "$cfg"\n\
chown claude:claude "$cfg"\n\
exec gosu claude "$@"\n' > /entrypoint.sh && chmod +x /entrypoint.sh

WORKDIR /work
ENTRYPOINT ["/entrypoint.sh"]
CMD ["claude"]
