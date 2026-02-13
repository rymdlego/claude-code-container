FROM ubuntu:24.04

ARG TARGETARCH

RUN apt-get update && apt-get install -y curl git make gosu jq && \
    GO_ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL https://go.dev/dl/go1.25.7.linux-${GO_ARCH}.tar.gz \
    | tar -xz -C /usr/local && \
    curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
    | sh -s -- -b /usr/local/bin && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/go/bin:${PATH}"

RUN useradd -m -s /bin/bash claude
USER claude
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/claude/.local/bin:${PATH}"

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
