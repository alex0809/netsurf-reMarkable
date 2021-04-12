#!/bin/bash

# Set up script for local development.
# This will setup the build directory by cloning libnsfb and netsurf-base

git clone https://github.com/alex0809/libnsfb-reMarkable.git ${BUILD_DIR}/libnsfb
git clone https://github.com/alex0809/netsurf-base-reMarkable.git ${BUILD_DIR}/netsurf
