#!/usr/bin/make -f

UID ?= $(shell id -u)
GID ?= $(shell id -g)
MAKEFILE_PATH ?= $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR ?= $(dir $(MAKEFILE_PATH))
BUILD_DIR ?= build
export BUILD_DIR

INSTALL_DESTINATION ?= 10.11.99.1


UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S), Darwin)
	 
    USE_VOLUME_MOUNT ?= YES
else
	USE_VOLUME_MOUNT ?= NO
endif

.PHONY: help all clean build install uninstall build-container copy-resources copy-binary local-dev

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: help ## Print this help

clean: ## Clean build directory and build volume
	rm -rf $(BUILD_DIR)
	docker volume rm -f netsurf-build

ifeq ($(USE_VOLUME_MOUNT), NO)
build: image ## Build netsurf in Docker container (bind mount BUILD_DIR as build directory)
	mkdir -p $(BUILD_DIR)
	docker run --rm \
	    --mount type=bind,source=$(MAKEFILE_DIR)/scripts,target=/opt/netsurf/scripts,readonly \
	    --mount type=bind,source=$(MAKEFILE_DIR)/$(BUILD_DIR),target=/opt/netsurf/build \
	    -e TARGET_WORKSPACE=/opt/netsurf/build \
	    --user=$(UID):$(GID) netsurf-build:latest \
	    /opt/netsurf/scripts/build.sh
else
build: image ## Build netsurf in Docker container (volume mount build directory except BUILD_DIR/netsurf, select with USE_VOLUME_MOUNT=YES)
	mkdir -p $(BUILD_DIR)/netsurf
	docker run --rm \
		--mount type=volume,source=netsurf-build,target=/opt/netsurf/build \
	    netsurf-build:latest \
		chown -R $(UID):$(GID) /opt/netsurf/build
	docker run --name netsurf-build \
	    --mount type=bind,source=$(MAKEFILE_DIR)/scripts,target=/opt/netsurf/scripts,readonly \
	    --mount type=volume,source=netsurf-build,target=/opt/netsurf/build \
	    --mount type=bind,source=$(MAKEFILE_DIR)/$(BUILD_DIR)/netsurf,target=/opt/netsurf/build/netsurf \
	    -e TARGET_WORKSPACE=/opt/netsurf/build \
	    --user=$(UID):$(GID) netsurf-build:latest \
	    /opt/netsurf/scripts/build.sh
	docker rm netsurf-build
endif

install: image build copy-resources copy-binary ## Build and copy binary and resources to device

uninstall: remove-resources remove-binary ## Uninstall binary and resources from device

image: ## Build the Docker image that is used for building netsurf
	docker build -t netsurf-build:latest .

copy-resources: ## Copy resources to device
	scp -r $(BUILD_DIR)/netsurf/frontends/framebuffer/res root@$(INSTALL_DESTINATION):/home/root/.netsurf/
	scp example/Choices root@$(INSTALL_DESTINATION):/home/root/.netsurf/

copy-binary: ## Copy binary to device
	scp $(BUILD_DIR)/netsurf/nsfb root@$(INSTALL_DESTINATION):/home/root/netsurf

remove-resources: ## Remove resources from device
	ssh root@$(INSTALL_DESTINATION) rm -rf /home/root/.netsurf

remove-binary: ## Remove binary from device
	ssh root@$(INSTALL_DESTINATION) rm -f /home/root/netsurf

local-dev: clean ## Clean build directory and check out HEAD of forked repositories
	scripts/setup_local_development.sh
