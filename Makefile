BUILDER_HOST := Builder
BUILDER_PATH := ~/projects/IDA-VNC
BUILDER_IMAGE_TAG := ida-vnc:9.4
HOST_PORT := 8443
VNC_PASSWORD := changeme
IDA_INSTALLER_SRC := /home/tylinux/Downloads/qbittorrent/ida94b1/ida-pro_94_x64linux.run
IDA_HEXLIC_HOST_PATH := /home/tylinux/ida.hexlic
WORKSPACE_HOST_PATH := /home/tylinux/IDA-workspace
CONTAINER_NAME := ida-vnc

all: sync build

sync:
	@echo "→ Syncing project to $(BUILDER_HOST):$(BUILDER_PATH) ..."
	rsync -avz --delete \
		--exclude='.git' \
		--exclude='.env' \
		--exclude='downloads/*.run' \
		--exclude='workspace/' \
		--exclude='*.hexlic' \
		-e ssh . $(BUILDER_HOST):$(BUILDER_PATH)

build: sync
	@echo "→ Building image on $(BUILDER_HOST) ..."
	ssh $(BUILDER_HOST) 'cd $(BUILDER_PATH) && \
		mkdir -p downloads && \
		if [ -f "$(IDA_INSTALLER_SRC)" ]; then \
			cp -l "$(IDA_INSTALLER_SRC)" downloads/ida-pro_94_x64linux.run 2>/dev/null || \
			cp "$(IDA_INSTALLER_SRC)" downloads/ida-pro_94_x64linux.run; \
		else \
			echo "ERROR: IDA installer not found at $(IDA_INSTALLER_SRC)"; \
			exit 1; \
		fi && \
		docker build -t $(BUILDER_IMAGE_TAG) . && \
		rm -f downloads/ida-pro_94_x64linux.run'

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
			/dockerstartup/custom_startup.sh \
			|| echo "Container already running or failed to start. Check with make logs"'

stop:
	@echo "→ Stopping container on $(BUILDER_HOST) ..."
	-ssh $(BUILDER_HOST) 'docker stop $(CONTAINER_NAME) && docker rm $(CONTAINER_NAME)'

restart: stop run

shell:
	ssh $(BUILDER_HOST) 'docker exec -it $(CONTAINER_NAME) bash'

logs:
	ssh $(BUILDER_HOST) 'docker logs -f $(CONTAINER_NAME)'

clean:
	-ssh $(BUILDER_HOST) 'docker rmi $(BUILDER_IMAGE_TAG)'

prune: stop
	-ssh $(BUILDER_HOST) 'docker rmi $(BUILDER_IMAGE_TAG) 2>/dev/null; docker volume prune -f'

help:
	@awk '/^## / { \
		gsub(/^## /, ""); \
		if (prev_target) print "  " prev_target " — " $$0; \
	} \
	/^[a-zA-Z0-9_-]+:/ { \
		prev_target = $$1; \
		gsub(/:/, "", prev_target); \
	}' $(MAKEFILE_LIST)
