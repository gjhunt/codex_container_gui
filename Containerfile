FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

# "latest" official ChatGPT Linux x64 package.
ARG CHATGPT_DEB_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"

# Use "latest" or pin this to a specific release for reproducibility.
ARG CODEX_VERSION=latest


# ----------------------------------------------------------------------
# Base packages
# ----------------------------------------------------------------------

RUN apt-get update && apt-get install -y\
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
# ChatGPT Linux desktop app
# ----------------------------------------------------------------------

RUN curl --proto '=https' --tlsv1.2 -fL \
        "${CHATGPT_DEB_URL}" \
        -o /tmp/chatgpt.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/chatgpt.deb \
    && rm -f /tmp/chatgpt.deb \
    && rm -rf /var/lib/apt/lists/*


# ----------------------------------------------------------------------
# Codex CLI
# ----------------------------------------------------------------------

RUN npm install -g "@openai/codex@${CODEX_VERSION}" \
    && codex --version


# ----------------------------------------------------------------------
# Non-root user matching the host user's UID/GID
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
# Environment
# ----------------------------------------------------------------------

ENV HOME=/home/chatgpt
ENV XDG_RUNTIME_DIR=/run/user/${UID}

# Xpra's private display.
ENV XPRA_DISPLAY=:100

# Port inside the container.
ENV XPRA_PORT=14500


# ----------------------------------------------------------------------
# ChatGPT graphical-session helper
#
# This runs INSIDE the private Xpra display.
#
# dbus-run-session creates a private D-Bus session.
# gnome-keyring-daemon provides an internal secret service when possible.
# ----------------------------------------------------------------------

RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -e' \
    '' \
    'if command -v gnome-keyring-daemon >/dev/null 2>&1; then' \
    '    eval "$(gnome-keyring-daemon --start --components=secrets 2>/dev/null)" || true' \
    'fi' \
    '' \
    'exec chatgpt "$@"' \
    > /usr/local/bin/chatgpt-session \
    && chmod 0755 /usr/local/bin/chatgpt-session


# ----------------------------------------------------------------------
# codex-cli
#
# Convenience name for the normal Codex CLI.
# You can also simply run "codex".
# ----------------------------------------------------------------------

RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'exec codex "$@"' \
    > /usr/local/bin/codex-cli \
    && chmod 0755 /usr/local/bin/codex-cli


# ----------------------------------------------------------------------
# codex-login
#
# Device-code authentication is useful in a container.
# ----------------------------------------------------------------------

RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'exec codex login --device-auth "$@"' \
    > /usr/local/bin/codex-login \
    && chmod 0755 /usr/local/bin/codex-login


# ----------------------------------------------------------------------
# codex-app
#
# Starts:
#
#   ChatGPT
#       |
#   private D-Bus
#       |
#   private X server (:100)
#       |
#   Xpra
#       |
#   TCP :14500
#
# Nothing here connects to the host X server.
# ----------------------------------------------------------------------

RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    '' \
    'DISPLAY_NUM="${XPRA_DISPLAY:-:100}"' \
    'PORT="${XPRA_PORT:-14500}"' \
    '' \
    'echo "Starting ChatGPT in private Xpra display ${DISPLAY_NUM}"' \
    'echo "Xpra container port: ${PORT}"' \
    'echo' \
    'echo "Attach from the host with:"' \
    'echo "  xpra attach tcp://127.0.0.1:${PORT}"' \
    'echo' \
    '' \
    'xpra start "${DISPLAY_NUM}" \' \
    '    --daemon=yes \' \
    '    --bind-tcp="0.0.0.0:${PORT}" \' \
    '    --tcp-auth=none \' \
    '    --html=no \' \
    '    --mdns=no \' \
    '    --clipboard=no \' \
    '    --printing=no \' \
    '    --speaker=no \' \
    '    --microphone=no \' \
    '    --file-transfer=no \' \
    '    --open-files=no \' \
    '    --exit-with-children=yes \' \
    '    --start-child="dbus-run-session -- /usr/local/bin/chatgpt-session"' \
    '' \
    'echo "ChatGPT/Xpra started."' \
    > /usr/local/bin/codex-app \
    && chmod 0755 /usr/local/bin/codex-app


# ----------------------------------------------------------------------
# codex-app-stop
# ----------------------------------------------------------------------

RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -e' \
    'xpra stop "${XPRA_DISPLAY:-:100}"' \
    > /usr/local/bin/codex-app-stop \
    && chmod 0755 /usr/local/bin/codex-app-stop


# ----------------------------------------------------------------------
# Shell environment
# ----------------------------------------------------------------------

RUN printf '%s\n' \
    '' \
    'echo "Container commands:"' \
    'echo "  codex            Codex CLI"' \
    'echo "  codex-cli        Codex CLI"' \
    'echo "  codex-login      Codex device-code login"' \
    'echo "  codex-app        Start ChatGPT GUI through Xpra"' \
    'echo "  codex-app-stop   Stop the Xpra/ChatGPT session"' \
    >> /etc/bash.bashrc


WORKDIR /workspace

USER ${UID}:${GID}

# Start in an ordinary Bash shell.
CMD ["/bin/bash"]