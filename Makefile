#!/usr/bin/make -f

UID ?= $(shell id -u)
GID ?= $(shell id -g)
MAKEFILE_PATH ?= $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR ?= $(dir $(MAKEFILE_PATH))
BUILD_DIR ?= build

INSTALL_DESTINATION ?= 10.11.99.1

.PHONY: all clean build install uninstall build-container copy-resources copy-binary local-dev

all: build

clean:
	rm -rf $(BUILD_DIR)

build: build-container
	mkdir -p $(BUILD_DIR)
	docker run --rm \
		--mount type=bind,source=$(MAKEFILE_DIR)/scripts,target=/opt/netsurf/scripts \
		--mount type=bind,source=$(MAKEFILE_DIR)/build,target=/opt/netsurf/build \
		-e TARGET_WORKSPACE=/opt/netsurf/build \
		--user=$(UID):$(GID) netsurf-build:latest \
		/opt/netsurf/scripts/build.sh

install: build copy-resources copy-binary

uninstall: remove-resources remove-binary

build-container:
	docker build -t netsurf-build:latest .

copy-resources:
	scp -r $(BUILD_DIR)/netsurf/resources root@$(INSTALL_DESTINATION):/home/root/.netsurf/
	scp example/Choices root@$(INSTALL_DESTINATION):/home/root/.netsurf/

copy-binary:
	scp $(BUILD_DIR)/netsurf/nsfb root@$(INSTALL_DESTINATION):/home/root/netsurf

remove-resources:
	ssh root@$(INSTALL_DESTINATION) rm -rf /home/root/.netsurf

remove-binary:
	ssh root@$(INSTALL_DESTINATION) rm -f /home/root/netsurf

local-dev: clean
	scripts/setup_local_development.sh
