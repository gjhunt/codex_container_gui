#!/usr/bin/env bash
set -euo pipefail

INSTANCE="${INSTANCE:-default}"
INSTANCE_SAFE="$(printf '%s' "$INSTANCE" | tr -c 'A-Za-z0-9_.-' '-')"

SOCKET_DIR="${XDG_RUNTIME_DIR}/chatgpt-xpra-${INSTANCE_SAFE}"

if [[ ! -d "$SOCKET_DIR" ]]; then
    echo "Xpra socket directory does not exist:"
    echo "  $SOCKET_DIR"
    exit 1
fi

# Find the actual Unix socket rather than relying on Xpra's
# display/hostname-based socket discovery.
mapfile -t SOCKETS < <(
    find "$SOCKET_DIR" \
        -maxdepth 1 \
        -type s \
        -name '*-100' \
        -print
)

if (( ${#SOCKETS[@]} == 0 )); then
    echo "No Xpra socket found in:"
    echo "  $SOCKET_DIR"
    echo
    echo "Run codex-app inside the container first."
    exit 1
fi

if (( ${#SOCKETS[@]} > 1 )); then
    echo "Multiple Xpra sockets found:"
    printf '  %s\n' "${SOCKETS[@]}"
    echo
    echo "Refusing to guess which session to attach to."
    exit 1
fi

SOCKET="${SOCKETS[0]}"

echo "Attaching to:"
echo "  $SOCKET"

exec xpra attach "$SOCKET" \
     --clipboard=yes \
     --clipboard-direction=to-client \
    --notifications=no \
    --printing=no \
    --speaker=no \
    --microphone=no \
    --webcam=no \
    --file-transfer=no \
    --open-files=no
