#!/bin/bash

# Set up script for local development.
# This will prepare clean and then setup the build directory by cloning libnsfb and netsurf-base

BUILD_DIR=build

rm -rf ${BUILD_DIR}
mkdir ${BUILD_DIR}

git clone https://github.com/alex0809/libnsfb-reMarkable.git ${BUILD_DIR}/libnsfb
git clone https://github.com/alex0809/netsurf-base-reMarkable.git ${BUILD_DIR}/netsurf
