#!/bin/bash

# Set up script for local development.
# This will setup the build directory by cloning libnsfb and netsurf-base

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

clone() {
    git clone https://github.com/alex0809/libnsfb-reMarkable.git ${BUILD_DIR}/libnsfb
    git clone https://github.com/alex0809/netsurf-base-reMarkable.git ${BUILD_DIR}/netsurf
    git clone https://github.com/alex0809/libhubbub-reMarkable.git ${BUILD_DIR}/libhubbub
}

if [ -z ${BUILD_DIR} ]; then echo "BUILD_DIR must be set" && exit 1; fi

case $1 in
    versioned)
        echo "Setting up fixed versions of repositories"
        clone
        source ${SCRIPT_DIR}/versions.sh
        pushd ${BUILD_DIR}/libnsfb
        git checkout ${LIBNSFB_VERSION}
        popd
        pushd ${BUILD_DIR}/netsurf
        git checkout ${NETSURF_VERSION}
        popd
        pushd ${BUILD_DIR}/libhubbub
        git checkout ${LIBHUBBUB_VERSION}
        popd
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

