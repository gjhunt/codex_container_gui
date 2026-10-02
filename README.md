# ChatGPT in an Xpra container

Run the official ChatGPT Linux desktop app and Codex CLI in a rootless Podman
container. The current directory is mounted as `/workspace`, application state
is kept in a named volume, and the desktop window is displayed through a private
Xpra Unix socket.

The default image currently targets x86-64 Linux because the upstream ChatGPT
package URL points to an AMD64 `.deb`.

## Prerequisites

Install these commands on the host:

- `podman`
- `xpra`
- `make`
- `realpath` (normally provided by GNU coreutils)

The launcher expects `XDG_RUNTIME_DIR` to be set by a normal desktop login.

## Build and install

From this repository, build the image and install the launchers:

```bash
make setup
```

`make build` and `make install` are also available as separate steps.

The second command installs launchers in `~/.local/bin`. If that directory is
not already on `PATH`, add this line to `~/.profile`, then log in again:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Use a different install location with, for example:

```bash
make install PREFIX=/usr/local
```

Remove the launchers with `make uninstall`. Uninstalling does not remove the
container image or the persistent home volumes.

## Everyday use

Change to a project and start the app:

```bash
cd ~/projects/my-project
chatgpt-start
```

This starts the container, waits for the GUI socket, and attaches Xpra. Closing
the ChatGPT app ends its Xpra server. If you only detach the Xpra client, the
container remains available and can be reattached:

```bash
chatgpt-attach
```

Other installed commands are:

```text
chatgpt-shell    Open an interactive container shell for the current project
chatgpt-stop     Stop and remove the current container
chatgpt-status   Show the container and socket state
chatgpt-clean    Remove stale sockets after the container has stopped
chatgpt-xpra     Access all commands through one command-line interface
```

Run `chatgpt-xpra --help` for the complete command syntax. The original
`./run-container.sh` and `./attach.sh` entry points remain available for
compatibility.

### A different project

The current directory is used by default. A path can also be supplied:

```bash
chatgpt-start ~/projects/another-project
chatgpt-shell ~/projects/another-project
```

### Multiple instances

Instances have independent containers, Xpra sockets, and home volumes:

```bash
chatgpt-start --instance work ~/projects/work
chatgpt-start --instance personal ~/projects/personal
chatgpt-attach --instance work
```

The `INSTANCE` environment variable is equivalent to `--instance`.

### Clipboard direction

The default, `to-client`, allows copying from the containerized app to the host
but prevents host-to-app paste. Enable two-way clipboard synchronization for a
session with:

```bash
XPRA_CLIPBOARD_DIRECTION=both chatgpt-start
```

Accepted values are `to-client`, `to-server`, and `both`. Use the same value
when attaching to an existing session.

### Codex login and manual mode

`chatgpt-shell` opens the older manual workflow. From that shell you can run:

```bash
codex-login
codex-app
```

Then attach from another host terminal with `chatgpt-attach`.

## Configuration

The image name defaults to `chatgpt-xpra`. Override it with `IMAGE` or the
launcher's `--image` option.

Builds intentionally follow the latest ChatGPT desktop package and Codex CLI by
default. For repeatable builds, pin both values:

```bash
make build \
  CODEX_VERSION=0.0.0 \
  CHATGPT_DEB_URL=https://example.invalid/chatgpt_amd64.deb \
  CHATGPT_DEB_SHA256=<sha256>
```

Replace the example values with a real published version, URL, and checksum.
`CHATGPT_DEB_SHA256` is optional; when provided, the build verifies the package
before installation.

Run `make help` to see all Make targets and configurable variables.

## Isolation model

The container:

- runs as the invoking host UID/GID through rootless Podman;
- uses a read-only root filesystem and `no-new-privileges`;
- persists `/home/chatgpt` in a per-instance named volume;
- mounts only the selected project read-write at `/workspace`;
- exposes Xpra through a mode-`0600` Unix socket in `XDG_RUNTIME_DIR`;
- disables Xpra file transfer, printing, notifications, audio, webcam, and open-file forwarding.

The selected project is intentionally writable so ChatGPT and Codex can modify
its files.

## Development checks

```bash
make check
```

This always checks Bash syntax and also runs ShellCheck when it is installed.

## Troubleshooting

- **Image not found:** run `make build` in this repository.
- **No Xpra socket:** inspect `chatgpt-status`, then try `chatgpt-stop` followed
  by `chatgpt-start`.
- **A stale socket remains:** stop the instance, then run `chatgpt-clean`.
- **The launcher command is missing:** ensure `~/.local/bin` is on `PATH`, or
  reinstall with `make install`.
- **An instance name is rejected:** use letters, numbers, dots, underscores, and
  hyphens, starting with a letter or number.
