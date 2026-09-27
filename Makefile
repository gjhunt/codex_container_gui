IMAGE ?= chatgpt-xpra

.PHONY: build run attach clean-socket

build:
	podman build \
		--build-arg UID=$$(id -u) \
		--build-arg GID=$$(id -g) \
		-t $(IMAGE) .

run:
	IMAGE=$(IMAGE) ./run-container.sh

attach:
	./attach.sh

clean-socket:
	rm -rf "$$XDG_RUNTIME_DIR/chatgpt-xpra-$${INSTANCE:-default}"
