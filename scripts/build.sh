#!/bin/bash

# Build script which sets up environment variables appropriately so cross-compilation
# works inside the docker container.
#
# Optimisation note (reMarkable Paper Pro):
#   The Paper Pro uses a Cortex-A53 (i.MX 8M Plus) at 1.8 GHz. We keep the
#   armhf ARMv7-A baseline (so the binary still runs on rM1/rM2) but tune
#   scheduling for A53 and enable NEON + hard-float + LTO. The same flags
#   are also used while building the third-party deps so the gains are not
#   undone at link time.

# Note: deliberately NOT using `set -e`. env.sh below uses patterns like
#   var=$(which cc); if [ $? -eq 0 ]; then ...
# which assume the previous command's failure is allowed. set -e would abort
# the whole script on those failures (silently if &>/dev/null is involved).

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
HOST=arm-remarkable-linux-gnueabihf

if [ -z "${TARGET_WORKSPACE:-}" ]; then echo "TARGET_WORKSPACE is required, but not set." && exit 1; fi

if [ -z "${MAKE:-}" ]; then export MAKE=make; fi

source $SCRIPTPATH/versions.sh
source $SCRIPTPATH/env.sh

# Performance + hardening flags applied to the netsurf tree itself.
# Keep them in sync with install_dependencies.sh so libs and binary agree.
NS_OPT_CFLAGS="-O2 -pipe -fomit-frame-pointer -ffunction-sections -fdata-sections"
NS_HARDEN_CFLAGS="-fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security -fno-plt"
NS_TUNE_CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard -mtune=cortex-a53"
NS_LDFLAGS_HARDEN="-Wl,-z,relro,-z,now -Wl,-z,noexecstack -Wl,--gc-sections -Wl,--as-needed"

# Required so the netsurf make picks up the previously built libraries
export CFLAGS="${CFLAGS:-} ${NS_OPT_CFLAGS} ${NS_HARDEN_CFLAGS} ${NS_TUNE_CFLAGS} -I$TARGET_WORKSPACE/inst-$HOST/include"
export CXXFLAGS="${CXXFLAGS:-} ${CFLAGS}"
export LDFLAGS="${LDFLAGS:-} ${NS_LDFLAGS_HARDEN} -L$TARGET_WORKSPACE/inst-$HOST/lib"
# freetype libs end up in /usr/local, so include that for pkg-config
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_LIBDIR:-}:$SYSROOT/usr/local/lib/pkgconfig"

# For local development, you can clone any repository into target workspace
# before running this script
ns-clone
ns-make-tools install
ns-make-libs install

cd $TARGET_WORKSPACE/netsurf/

# libevdev / pthread are picked up by the framebuffer frontend; -lm is needed
# explicitly by some new libs under --as-needed.
export LDFLAGS="$LDFLAGS -levdev -lpthread -lm"

export CC="arm-remarkable-linux-gnueabihf-gcc"
export STRIP="arm-remarkable-linux-gnueabihf-strip"
$MAKE TARGET=framebuffer NETSURF_FB_FONTLIB=freetype NETSURF_STRIP_BINARY=YES NETSURF_USE_LIBICONV_PLUG=NO NETSURF_USE_DUKTAPE=NO NETSURF_REMARKABLE=YES
