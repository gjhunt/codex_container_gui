build: Containerfile
	podman build \
	    --build-arg UID="$$(id -u)" \
	    --build-arg GID="$$(id -g)" \
	    -t chatgpt-x11 .

run:
	podman run --rm -it \
		--name chatgpt-gui \
		--userns=keep-id \
		--shm-size=1g \
		-p 127.0.0.1:14500:14500 \
		-v chatgpt-home:/home/chatgpt \
		-v "$$(pwd):/workspace:rw" \
		-w /workspace \
		chatgpt-x11
vol:
	podman volume create chatgpt-home
