FROM ghcr.io/actions/actions-runner:latest

USER root

# Common CI tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates gnupg lsb-release jq unzip zip \
    && rm -rf /var/lib/apt/lists/*

# Node.js 20 — required by ALL JS-based GitHub Actions (actions/checkout,
# actions/setup-*, hashicorp/setup-terraform, azure/login, etc). The
# ghcr.io/actions/actions-runner base image does NOT ship node; without
# this every JS action fails with `/usr/bin/env: 'node': No such file or
# directory` (exit 127). Mirrors martinopedal/personal-runners-infra.
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Azure CLI (official install script)
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Terraform (latest stable from HashiCorp APT repo)
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
       > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y terraform \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /home/runner/entrypoint.sh
# Defence-in-depth: strip CR if entrypoint.sh ever sneaks in with CRLF.
# Linux kernel reads "#!/bin/bash\r" literally → exec ENOENT on the interpreter.
RUN sed -i 's/\r$//' /home/runner/entrypoint.sh \
    && chmod +x /home/runner/entrypoint.sh

USER runner
WORKDIR /home/runner
ENTRYPOINT ["/home/runner/entrypoint.sh"]
