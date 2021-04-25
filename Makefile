#!/usr/bin/make -f

UID ?= $(shell id -u)
GID ?= $(shell id -g)
MAKEFILE_PATH ?= $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR ?= $(dir $(MAKEFILE_PATH))
BUILD_DIR ?= build
export BUILD_DIR

INSTALL_DESTINATION ?= 10.11.99.1

.PHONY: help all clean build install uninstall build-container copy-resources copy-binary local-dev

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

all: help ## Print this help

clean: ## Clean build directory
	rm -rf $(BUILD_DIR)

build: ## Build netsurf in Docker container
	mkdir -p $(BUILD_DIR)
	docker run --rm \
		--mount type=bind,source=$(MAKEFILE_DIR)/scripts,target=/opt/netsurf/scripts \
		--mount type=bind,source=$(MAKEFILE_DIR)/build,target=/opt/netsurf/build \
		-e TARGET_WORKSPACE=/opt/netsurf/build \
		--user=$(UID):$(GID) netsurf-build:latest \
		/opt/netsurf/scripts/build.sh

install: build copy-resources copy-binary ## Build and copy binary and resources to device

uninstall: remove-resources remove-binary ## Uninstall binary and resources from device

build-container: ## Build the Docker container that is used for building netsurf
	docker build -t netsurf-build:latest .

copy-resources: ## Copy resources to device
	scp -r $(BUILD_DIR)/netsurf/resources root@$(INSTALL_DESTINATION):/home/root/.netsurf/
	scp example/Choices root@$(INSTALL_DESTINATION):/home/root/.netsurf/

copy-binary: ## Copy binary to device
	scp $(BUILD_DIR)/netsurf/nsfb root@$(INSTALL_DESTINATION):/home/root/netsurf

remove-resources: ## Remove resources from device
	ssh root@$(INSTALL_DESTINATION) rm -rf /home/root/.netsurf

remove-binary: ## Remove binary from device
	ssh root@$(INSTALL_DESTINATION) rm -f /home/root/netsurf

local-dev: clean ## Clean build directory and check out HEAD of forked repositories
	scripts/setup_local_development.sh
