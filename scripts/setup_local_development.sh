#!/bin/bash

# Set up script for local development.
# This will setup the build directory by cloning libnsfb and netsurf-base.
#
# Uses HTTPS clone URLs so it works for anyone without a GitHub SSH key
# configured. The repositories themselves are public read-only forks.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

LIBNSFB_URL="${LIBNSFB_URL:-https://github.com/alex0809/libnsfb-reMarkable.git}"
NETSURF_URL="${NETSURF_URL:-https://github.com/alex0809/netsurf-base-reMarkable.git}"

clone() {
    git clone "${LIBNSFB_URL}" "${BUILD_DIR}/libnsfb"
    git clone "${NETSURF_URL}" "${BUILD_DIR}/netsurf"
}

if [ -z "${BUILD_DIR}" ]; then echo "BUILD_DIR must be set" && exit 1; fi

case $1 in
    versioned)
        echo "Setting up fixed versions of repositories"
        clone
        source ${SCRIPT_DIR}/versions.sh
        git -C "${BUILD_DIR}/libnsfb" -c advice.detachedHead=false checkout "${LIBNSFB_VERSION}"
        git -C "${BUILD_DIR}/netsurf" -c advice.detachedHead=false checkout "${NETSURF_VERSION}"
        ;;
    head)
        echo "Setting up HEAD of repositories"
        clone
        ;;
    *)
        echo "You must run the script with the first argument either 'versioned' or 'head'"
        exit 1
        ;;
esac
