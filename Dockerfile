# Pinned to a specific digest so rebuilds are reproducible. To refresh deliberately:
#   docker pull debian:bookworm-slim && docker inspect --format='{{index .RepoDigests 0}}' debian:bookworm-slim
FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

ARG KUBECTL_VERSION=1.31.0
ARG HELM_VERSION=3.16.2
ARG TERRAFORM_VERSION=1.9.8
ARG TARGETARCH=arm64

# sha256 checksums pinned to the versions above (linux/arm64). Update together when bumping a version:
#   kubectl:   curl -sL https://dl.k8s.io/release/v<ver>/bin/linux/arm64/kubectl.sha256
#   helm:      curl -sL https://get.helm.sh/helm-v<ver>-linux-arm64.tar.gz.sha256sum
#   terraform: curl -sL https://releases.hashicorp.com/terraform/<ver>/terraform_<ver>_SHA256SUMS | grep linux_arm64
ARG KUBECTL_SHA256=f42832db7d77897514639c6df38214a6d8ae1262ee34943364ec1ffaee6c009c
ARG HELM_SHA256=1888301aeb7d08a03b6d9f4d2b73dcd09b89c41577e80e3455c113629fc657a4
ARG TERRAFORM_SHA256=f85868798834558239f6148834884008f2722548f84034c9b0f62934b2d73ebb

ENV DEBIAN_FRONTEND=noninteractive

# Base OS packages + prereqs for adding third-party apt repos
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    git \
    vim \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22.x (Debian bookworm ships Node 18, too old for Claude Code which requires >=22)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI only (client) — talks to host daemon via mounted socket, no engine/daemon installed here
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# kubectl (pinned + checksum-verified)
RUN curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
    && echo "${KUBECTL_SHA256}  /usr/local/bin/kubectl" | sha256sum -c - \
    && chmod +x /usr/local/bin/kubectl

# helm (pinned + checksum-verified)
RUN curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" -o /tmp/helm.tar.gz \
    && echo "${HELM_SHA256}  /tmp/helm.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/helm.tar.gz -C /tmp \
    && mv /tmp/linux-${TARGETARCH}/helm /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm \
    && rm -rf /tmp/helm.tar.gz /tmp/linux-${TARGETARCH}

# terraform (pinned + checksum-verified)
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" -o /tmp/terraform.zip \
    && echo "${TERRAFORM_SHA256}  /tmp/terraform.zip" | sha256sum -c - \
    && unzip -o /tmp/terraform.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/terraform \
    && rm -f /tmp/terraform.zip

# AWS CLI v2 (official installer, arch-aware)
RUN ARCH=$(uname -m) \
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws

# Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

CMD ["/bin/bash"]
