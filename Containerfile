FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

ARG CHATGPT_DEB_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"
ARG CODEX_VERSION=latest


# ----------------------------------------------------------------------
# Runtime dependencies
# ----------------------------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus \
        dbus-x11 \
        gnome-keyring \
        libsecret-1-0 \
        xdg-utils \
        git \
        bash \
        procps \
        less \
        nano \
        vim-tiny \
        bubblewrap \
        nodejs \
        npm \
        xpra \
        xvfb \
        xauth \
        epiphany-browser \
        python3-pil \
        python3-dbus \
        python3-lz4 \
        python3-pyinotify \
        python3-xdg \
        python3-netifaces \
    && rm -rf /var/lib/apt/lists/*


# ----------------------------------------------------------------------
# Official ChatGPT Linux desktop app
# ----------------------------------------------------------------------

RUN curl --proto '=https' --tlsv1.2 -fL \
        "${CHATGPT_DEB_URL}" \
        -o /tmp/chatgpt.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/chatgpt.deb \
    && rm -f /tmp/chatgpt.deb \
    && rm -rf /var/lib/apt/lists/*


# ----------------------------------------------------------------------
# Official Codex CLI
# ----------------------------------------------------------------------

RUN npm install -g "@openai/codex@${CODEX_VERSION}" \
    && codex --version


# ----------------------------------------------------------------------
# Create / adapt non-root user to match host UID/GID
# ----------------------------------------------------------------------

RUN set -eux; \
    test -n "${UID}"; \
    test -n "${GID}"; \
    \
    if ! getent group "${GID}" >/dev/null; then \
        groupadd --gid "${GID}" chatgpt; \
    fi; \
    \
    if getent passwd "${UID}" >/dev/null; then \
        existing_user="$(getent passwd "${UID}" | cut -d: -f1)"; \
        usermod \
            --gid "${GID}" \
            --home /home/chatgpt \
            --shell /bin/bash \
            "${existing_user}"; \
    else \
        useradd \
            --uid "${UID}" \
            --gid "${GID}" \
            --home-dir /home/chatgpt \
            --shell /bin/bash \
            chatgpt; \
    fi; \
    \
    mkdir -p \
        /home/chatgpt \
        /workspace \
        "/run/user/${UID}"; \
    \
    chown -R "${UID}:${GID}" \
        /home/chatgpt \
        /workspace \
        "/run/user/${UID}"; \
    \
    chmod 700 "/run/user/${UID}"


# ----------------------------------------------------------------------
# Helper scripts
# ----------------------------------------------------------------------

COPY scripts/chatgpt-session    /usr/local/bin/chatgpt-session
COPY scripts/codex-app          /usr/local/bin/codex-app
COPY scripts/codex-app-stop     /usr/local/bin/codex-app-stop
COPY scripts/codex-login        /usr/local/bin/codex-login

RUN chmod 0755 \
        /usr/local/bin/chatgpt-session \
        /usr/local/bin/codex-app \
        /usr/local/bin/codex-app-stop \
        /usr/local/bin/codex-login


# ----------------------------------------------------------------------
# Environment
# ----------------------------------------------------------------------

ENV HOME=/home/chatgpt
ENV XDG_RUNTIME_DIR=/run/user/${UID}

ENV XPRA_DISPLAY=:100
ENV XPRA_SOCKET_DIR=/xpra-host

# Helps xdg-open choose the containerized browser for OAuth / links.
ENV BROWSER=epiphany-browser

WORKDIR /workspace

USER ${UID}:${GID}

CMD ["/bin/bash"]