# ---------------------------------------------------------------------------
# IDA Pro + KasmVNC — Mac → Builder remote build automation
# ---------------------------------------------------------------------------
# Usage:
#   1. Copy .env.template to .env and fill in your paths.
#   2. Place your IDA installer at downloads/ida-pro_94_x64linux.run on the Builder.
#   3. Run: make all && make run
# ---------------------------------------------------------------------------

# Load local overrides from .env (gitignored)
-include .env

# --- Defaults ---
BUILDER_HOST     ?= Builder
BUILDER_PATH     ?= ~/projects/IDA-VNC
BUILDER_IMAGE_TAG ?= ida-vnc:9.4
HOST_PORT        ?= 8443
VNC_PASSWORD     ?= changeme
CONTAINER_NAME   ?= ida-vnc

# Where the installer lives on the Builder (relative to BUILDER_PATH or absolute)
# If you put it elsewhere, override this in .env.
IDA_INSTALLER    ?= downloads/ida-pro_94_x64linux.run

# Host-side paths for runtime mounts (override in .env)
IDA_HEXLIC_HOST_PATH ?= $(HOME)/ida.hexlic
WORKSPACE_HOST_PATH  ?= $(HOME)/IDA-workspace

.EXPORT_ALL_VARIABLES:

.PHONY: all sync build run stop restart shell logs clean prune help

all: sync build

## sync — Push project source to Builder via rsync
sync:
	@echo "→ Syncing project to $(BUILDER_HOST):$(BUILDER_PATH) ..."
	rsync -avz --delete \
		--exclude='.git' \
		--exclude='.env' \
		--exclude='downloads/*.run' \
		--exclude='workspace/' \
		--exclude='*.hexlic' \
		-e ssh . $(BUILDER_HOST):$(BUILDER_PATH)

## build — Build the Docker image on Builder
build: sync
	@echo "→ Building image on $(BUILDER_HOST) ..."
	ssh $(BUILDER_HOST) 'cd $(BUILDER_PATH) && \
		if [ -f "$(IDA_INSTALLER)" ]; then \
			docker build -t $(BUILDER_IMAGE_TAG) .; \
		else \
			echo "ERROR: IDA installer not found at $(BUILDER_PATH)/$(IDA_INSTALLER)"; \
			echo "Please copy your installer to the Builder:"; \
			echo "  scp ida-pro_94_x64linux.run $(BUILDER_HOST):$(BUILDER_PATH)/$(IDA_INSTALLER)"; \
			exit 1; \
		fi'

## run — Start the container on Builder
run:
	@echo "→ Starting container on $(BUILDER_HOST) ..."
	ssh $(BUILDER_HOST) 'cd $(BUILDER_PATH) && \
		docker run -d \
			--name $(CONTAINER_NAME) \
			--hostname ida-vnc \
			-p $(HOST_PORT):6901 \
			-e VNC_PW=$(VNC_PASSWORD) \
			-e HOME=/home/kasm-user \
			-v $(WORKSPACE_HOST_PATH):/home/kasm-user/workspace \
			-v $(IDA_HEXLIC_HOST_PATH):/home/kasm-user/.idapro/ida.hexlic:ro \
			$(BUILDER_IMAGE_TAG) \
			|| echo "Container already running or failed to start. Check with make logs"'

## stop — Stop and remove the container
stop:
	@echo "→ Stopping container on $(BUILDER_HOST) ..."
	-ssh $(BUILDER_HOST) 'docker stop $(CONTAINER_NAME) && docker rm $(CONTAINER_NAME)'

## restart — Stop + Run
restart: stop run

## shell — Interactive shell into running container
shell:
	ssh $(BUILDER_HOST) 'docker exec -it $(CONTAINER_NAME) bash'

## logs — Tail container logs
logs:
	ssh $(BUILDER_HOST) 'docker logs -f $(CONTAINER_NAME)'

## clean — Remove image from Builder
 clean:
	-ssh $(BUILDER_HOST) 'docker rmi $(BUILDER_IMAGE_TAG)'

## prune — Deep cleanup: stop + rm + image removal + volume cleanup
prune: stop
	-ssh $(BUILDER_HOST) 'docker rmi $(BUILDER_IMAGE_TAG) 2>/dev/null; docker volume prune -f'

## help — Show this help
help:
	@awk '/^## / { \
		gsub(/^## /, ""); \
		if (prev_target) print "  " prev_target " — " $$0; \
	} \
	/^[a-zA-Z0-9_-]+:/ { \
		prev_target = $$1; \
		gsub(/:/, "", prev_target); \
	}' $(MAKEFILE_LIST)
