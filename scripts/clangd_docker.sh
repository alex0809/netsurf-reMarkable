#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

docker exec -i netsurf-clangd clangd --cross-file-rename --path-mappings=${SCRIPT_DIR%/*}/build=/opt/netsurf/build,${SCRIPT_DIR%/*}/build/x-tools=/opt/x-tools --query-driver="/opt/x-tools/arm-remarkable-linux-gnueabihf/bin/*-gcc" ${@:1}
