IMAGE ?= chatgpt-xpra
INSTANCE ?= default
PROJECT ?= $(CURDIR)
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
CODEX_VERSION ?= latest
CHATGPT_DEB_URL ?= https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb
CHATGPT_DEB_SHA256 ?=

.PHONY: help setup build install uninstall start run shell attach stop status clean-socket check

help:
	@echo "Targets:"
	@echo "  setup         Build the image and install the launchers"
	@echo "  build         Build the container image"
	@echo "  install       Install launchers into $(BINDIR)"
	@echo "  uninstall     Remove launchers from $(BINDIR)"
	@echo "  start         Start ChatGPT for PROJECT and attach"
	@echo "  shell         Open a container shell for PROJECT"
	@echo "  attach        Attach to the running GUI"
	@echo "  stop          Stop this instance"
	@echo "  status        Show this instance's status"
	@echo "  clean-socket  Remove this instance's stale socket"
	@echo "  check         Run local script checks"
	@echo
	@echo "Variables: IMAGE, INSTANCE, PROJECT, PREFIX, CODEX_VERSION,"
	@echo "           CHATGPT_DEB_URL, CHATGPT_DEB_SHA256"

setup: build install

build:
	podman build \
		--build-arg UID=$$(id -u) \
		--build-arg GID=$$(id -g) \
		--build-arg CODEX_VERSION="$(CODEX_VERSION)" \
		--build-arg CHATGPT_DEB_URL="$(CHATGPT_DEB_URL)" \
		--build-arg CHATGPT_DEB_SHA256="$(CHATGPT_DEB_SHA256)" \
		-t "$(IMAGE)" .

install:
	install -d "$(DESTDIR)$(BINDIR)"
	install -m 0755 chatgpt-xpra "$(DESTDIR)$(BINDIR)/chatgpt-xpra"
	ln -sfn chatgpt-xpra "$(DESTDIR)$(BINDIR)/chatgpt-start"
	ln -sfn chatgpt-xpra "$(DESTDIR)$(BINDIR)/chatgpt-shell"
	ln -sfn chatgpt-xpra "$(DESTDIR)$(BINDIR)/chatgpt-attach"
	ln -sfn chatgpt-xpra "$(DESTDIR)$(BINDIR)/chatgpt-stop"
	ln -sfn chatgpt-xpra "$(DESTDIR)$(BINDIR)/chatgpt-status"
	ln -sfn chatgpt-xpra "$(DESTDIR)$(BINDIR)/chatgpt-clean"
	@echo "Installed launchers in $(DESTDIR)$(BINDIR)"

uninstall:
	rm -f \
		"$(DESTDIR)$(BINDIR)/chatgpt-xpra" \
		"$(DESTDIR)$(BINDIR)/chatgpt-start" \
		"$(DESTDIR)$(BINDIR)/chatgpt-shell" \
		"$(DESTDIR)$(BINDIR)/chatgpt-attach" \
		"$(DESTDIR)$(BINDIR)/chatgpt-stop" \
		"$(DESTDIR)$(BINDIR)/chatgpt-status" \
		"$(DESTDIR)$(BINDIR)/chatgpt-clean"

start:
	INSTANCE="$(INSTANCE)" IMAGE="$(IMAGE)" ./chatgpt-xpra start "$(PROJECT)"

run: shell

shell:
	INSTANCE="$(INSTANCE)" IMAGE="$(IMAGE)" ./chatgpt-xpra shell "$(PROJECT)"

attach:
	INSTANCE="$(INSTANCE)" ./chatgpt-xpra attach

stop:
	INSTANCE="$(INSTANCE)" ./chatgpt-xpra stop

status:
	INSTANCE="$(INSTANCE)" ./chatgpt-xpra status

clean-socket:
	INSTANCE="$(INSTANCE)" ./chatgpt-xpra clean

check:
	bash -n chatgpt-xpra attach.sh run-container.sh scripts/*
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck chatgpt-xpra attach.sh run-container.sh scripts/*; \
	else \
		echo "shellcheck not installed; skipped"; \
	fi
