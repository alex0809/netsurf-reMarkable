#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
docker exec -i netsurf-clangd clangd --path-mappings=${SCRIPT_DIR%/*}/build=/opt/netsurf/build ${@:1}
