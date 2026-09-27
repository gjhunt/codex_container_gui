#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-chatgpt-xpra}"
INSTANCE="${INSTANCE:-default}"

PROJECT="${1:-$PWD}"
PROJECT="$(realpath "$PROJECT")"

if [[ ! -d "$PROJECT" ]]; then
    echo "Project directory does not exist:"
    echo "  $PROJECT"
    exit 1
fi

if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
    echo "XDG_RUNTIME_DIR is not set."
    exit 1
fi

# Keep instance names filesystem/container friendly.
INSTANCE_SAFE="$(printf '%s' "$INSTANCE" | tr -c 'A-Za-z0-9_.-' '-')"

if [[ "$INSTANCE_SAFE" == "default" ]]; then
    HOME_VOLUME="chatgpt-home"
else
    HOME_VOLUME="chatgpt-home-${INSTANCE_SAFE}"
fi

CONTAINER_NAME="chatgpt-gui-${INSTANCE_SAFE}"
SOCKET_DIR="${XDG_RUNTIME_DIR}/chatgpt-xpra-${INSTANCE_SAFE}"

mkdir -p "$SOCKET_DIR"
chmod 700 "$SOCKET_DIR"

if ! podman volume inspect "$HOME_VOLUME" >/dev/null 2>&1; then
    podman volume create "$HOME_VOLUME" >/dev/null
fi

echo "Container:     $CONTAINER_NAME"
echo "Project:       $PROJECT"
echo "Home volume:   $HOME_VOLUME"
echo "Xpra socket:   $SOCKET_DIR"

exec podman run --rm -it \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --userns=keep-id \
    --shm-size=1g \
    --pids-limit=2048 \
    -e XPRA_DISPLAY=:100 \
    -e XPRA_SOCKET_DIR=/xpra-host \
    -v "${HOME_VOLUME}:/home/chatgpt:U" \
    -v "${PROJECT}:/workspace:rw" \
    -v "${SOCKET_DIR}:/xpra-host:rw" \
    -w /workspace \
    "$IMAGE"



