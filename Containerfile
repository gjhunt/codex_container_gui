FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

ARG CHATGPT_DEB_URL="https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb"

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dbus \
        dbus-x11 \
        gnome-keyring \
        libsecret-1-0 \
        xauth \
        xdg-utils \
        git \
        bash \
        procps \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -fL \
        "$CHATGPT_DEB_URL" \
        -o /tmp/chatgpt.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/chatgpt.deb \
    && rm -f /tmp/chatgpt.deb \
    && rm -rf /var/lib/apt/lists/*

# Create a container user matching the host UID/GID.
RUN set -eux; \
    if ! getent group "${GID}" >/dev/null; then \
        groupadd --gid "${GID}" chatgpt; \
    fi; \
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
    mkdir -p /home/chatgpt /workspace; \
    chown -R "${UID}:${GID}" /home/chatgpt /workspace

ENV HOME=/home/chatgpt
ENV XDG_SESSION_TYPE=x11

WORKDIR /workspace

USER ${UID}:${GID}

# Give ChatGPT its own private D-Bus session.
#CMD ["dbus-run-session", "--", "chatgpt"]