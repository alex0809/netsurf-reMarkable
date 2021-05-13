#!/usr/bin/make -f

UID ?= $(shell id -u)
GID ?= $(shell id -g)
MAKEFILE_PATH ?= $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR ?= $(dir $(MAKEFILE_PATH))
BUILD_DIR ?= build
export BUILD_DIR
INSTALL_DESTINATION ?= 10.11.99.1
IMAGE_TAG ?= latest
CLANGD_CONTAINER ?= netsurf-clangd

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S), Darwin)
    USE_VOLUME_MOUNT ?= YES
else
	USE_VOLUME_MOUNT ?= NO
endif

.PHONY: help all clean build install uninstall image copy-resources copy-binary remove-resources remove-binary checkout clangd-build clangd-start clangd-stop

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: help ## Print this help

clean: ## Clean build directory, build volume and clangd container
	rm -rf $(BUILD_DIR)
	docker volume rm -f netsurf-build
	docker rm -f $(CLANGD_CONTAINER)

ifeq ($(USE_VOLUME_MOUNT), NO)
build: ## Build netsurf in Docker container (bind mount BUILD_DIR as build directory)
	mkdir -p $(BUILD_DIR)
	docker run --rm \
	    --mount type=bind,source=$(MAKEFILE_DIR)/scripts,target=/opt/netsurf/scripts,readonly \
	    --mount type=bind,source=$(MAKEFILE_DIR)/$(BUILD_DIR),target=/opt/netsurf/build \
	    -e TARGET_WORKSPACE=/opt/netsurf/build \
	    --user=$(UID):$(GID) netsurf-build:$(IMAGE_TAG) \
	    /opt/netsurf/scripts/build.sh
else
build: ## Build netsurf in Docker container (volume mount build directory except BUILD_DIR/netsurf, select with USE_VOLUME_MOUNT=YES)
	$(info Using volume mount for build directory)
# Workaround: clone all bind-mounted repositories outside the container, 
# because we need the folders to exist before the container starts for mounting them.
# Only call setup if BUILD_DIR does not exist yet.
	if [ ! -d $(BUILD_DIR) ]; then mkdir -p $(BUILD_DIR) && scripts/setup_local_development.sh versioned; fi
# chown the build directory volume to the current user, so the build can run as current user
	docker run --rm \
		--mount type=volume,source=netsurf-build,target=/opt/netsurf/build \
	    netsurf-build:$(IMAGE_TAG) \
		chown -R $(UID):$(GID) /opt/netsurf/build
	docker run --rm \
	    --mount type=bind,source=$(MAKEFILE_DIR)/scripts,target=/opt/netsurf/scripts,readonly \
	    --mount type=volume,source=netsurf-build,target=/opt/netsurf/build \
	    --mount type=bind,source=$(MAKEFILE_DIR)/$(BUILD_DIR)/netsurf,target=/opt/netsurf/build/netsurf \
	    --mount type=bind,source=$(MAKEFILE_DIR)/$(BUILD_DIR)/libnsfb,target=/opt/netsurf/build/libnsfb \
	    -e TARGET_WORKSPACE=/opt/netsurf/build \
	    --user=$(UID):$(GID) netsurf-build:$(IMAGE_TAG) \
	    /opt/netsurf/scripts/build.sh
endif

install: image build copy-resources copy-binary ## Build and copy binary and resources to device

uninstall: remove-resources remove-binary ## Uninstall binary and resources from device

image: ## Build the Docker image that is used for building netsurf
	docker build -t netsurf-build:$(IMAGE_TAG) .

copy-resources: ## Copy resources to device
	scp -r $(BUILD_DIR)/netsurf/frontends/framebuffer/res root@$(INSTALL_DESTINATION):/home/root/.netsurf/
	scp example/Choices root@$(INSTALL_DESTINATION):/home/root/.netsurf/

copy-binary: ## Copy binary to device
	scp $(BUILD_DIR)/netsurf/nsfb root@$(INSTALL_DESTINATION):/home/root/netsurf

remove-resources: ## Remove resources from device
	ssh root@$(INSTALL_DESTINATION) rm -rf /home/root/.netsurf

remove-binary: ## Remove binary from device
	ssh root@$(INSTALL_DESTINATION) rm -f /home/root/netsurf

checkout: clean ## [Dev] Clean build directory and check out HEAD of forked repositories
	scripts/setup_local_development.sh head

clangd-build: ## [Dev] Prepare local dev container with clangd and compile-commands.json (Note: run checkout first to use HEAD)
	mkdir -p $(BUILD_DIR)
	docker rm -f $(CLANGD_CONTAINER)
	docker build -t netsurf-localdev -f Dockerfile.localdev .
	docker run --rm \
		--mount type=bind,source=$(MAKEFILE_DIR)/$(BUILD_DIR),target=/opt/netsurf/build \
	    netsurf-localdev:latest \
		chown -R $(UID):$(GID) /opt/netsurf/build
	docker run --rm \
		--mount type=bind,source=$(MAKEFILE_DIR)/scripts,target=/opt/netsurf/scripts \
		--mount type=bind,source=$(MAKEFILE_DIR)/$(BUILD_DIR),target=/opt/netsurf/build \
		-e TARGET_WORKSPACE=/opt/netsurf/build \
		-e MAKE="bear --append -- make" \
		--user=$(UID):$(GID) netsurf-localdev:latest \
		sh -c "cd /opt/netsurf/build && /opt/netsurf/scripts/build.sh"

clangd-start: ## [Dev] Start the local development docker container with clangd set up
	$(info To access clangd-container, you can use scripts/clangd_docker.sh.)
	docker run --detach --name netsurf-clangd \
		--mount type=bind,source=$(MAKEFILE_DIR)/scripts,target=/opt/netsurf/scripts \
		--mount type=bind,source=$(MAKEFILE_DIR)/$(BUILD_DIR),target=/opt/netsurf/build \
		-p 50505:50505 \
		--user=$(UID):$(GID) netsurf-localdev:latest \
		tail -f /dev/null
# Requires sudo to be able to copy the x-tools directory recursively to host
	sudo docker cp -a netsurf-clangd:/opt/x-tools \
		$(MAKEFILE_DIR)/$(BUILD_DIR)
# Change ownership to curent user and add write permission, so we don't need sudo for later deletion
	sudo chown -R $(UID):$(GID) $(BUILD_DIR)/x-tools
	chmod +w $(BUILD_DIR)/x-tools

clangd-stop: ## [Dev] Stop the local development docker container
	docker rm -f netsurf-clangd
