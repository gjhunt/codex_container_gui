build: Containerfile
	podman build \
	    --build-arg UID="$$(id -u)" \
	    --build-arg GID="$$(id -g)" \
	    -t chatgpt-x11 .

run:
	XAUTH_FILE="$${XAUTHORITY:-$$HOME/.Xauthority}"; \
	echo "DISPLAY=$$DISPLAY"; \
	echo "XAUTH_FILE=$$XAUTH_FILE"; \
	test -f "$$XAUTH_FILE"; \
	podman run --rm -it \
		--name chatgpt-gui \
		--userns=keep-id \
		--shm-size=1g \
		-e DISPLAY="$$DISPLAY" \
		-e XAUTHORITY=/tmp/host-xauthority \
		-e XDG_SESSION_TYPE=x11 \
		-v /tmp/.X11-unix:/tmp/.X11-unix:ro \
		-v "$$XAUTH_FILE:/tmp/host-xauthority:ro" \
		-v chatgpt-home:/home/chatgpt \
		-v "$$PWD:/workspace:rw" \
		-w /workspace \
		chatgpt-x11

vol:
	podman volume create chatgpt-home
