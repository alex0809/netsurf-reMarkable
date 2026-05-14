#!/bin/bash

# Build script for NetSurf targeting reMarkable Paper Pro (aarch64).
# Cross-compilation runs inside the Docker image built from ./Dockerfile.
#
# Optimisation note (Paper Pro / i.MX 8M Mini, 4x Cortex-A53 @ 1.8 GHz):
#   aarch64 has NEON / hard-float as ISA features (no -mfpu/-mfloat-abi
#   needed). We tune for Cortex-A53 and turn on the same hardening
#   flags used while building the third-party deps.
#
# Caveat: the libnsfb-reMarkable / netsurf-base-reMarkable forks pinned in
# versions.sh were written for rM1/rM2's e-ink controller. The aarch64
# binary will compile but the framebuffer/refresh code may not drive the
# Paper Pro's display correctly. See PAPER_PRO_FRAMEBUFFER_NOTES.md.

# Note: deliberately NOT using `set -e`. env.sh uses patterns like
#   var=$(which cc); if [ $? -eq 0 ]; then ...
# which assume the previous command's failure is allowed.

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
HOST=aarch64-linux-gnu

if [ -z "${TARGET_WORKSPACE:-}" ]; then echo "TARGET_WORKSPACE is required, but not set." && exit 1; fi
if [ -z "${SYSROOT:-}" ]; then echo "SYSROOT must be set by the Dockerfile." && exit 1; fi

if [ -z "${MAKE:-}" ]; then export MAKE=make; fi

source $SCRIPTPATH/versions.sh
source $SCRIPTPATH/env.sh

# Performance + hardening flags applied to the netsurf tree itself.
# Keep them in sync with install_dependencies.sh so libs and binary agree.
NS_OPT_CFLAGS="-O2 -pipe -fomit-frame-pointer -ffunction-sections -fdata-sections"
NS_HARDEN_CFLAGS="-fstack-protector-strong -D_FORTIFY_SOURCE=2 -Wformat -Wformat-security -fno-plt"
NS_TUNE_CFLAGS="-march=armv8-a+crc -mtune=cortex-a53"
NS_LDFLAGS_HARDEN="-Wl,-z,relro,-z,now -Wl,-z,noexecstack -Wl,--gc-sections"

# Pull in headers/libs from both our isolated sysroot ($SYSROOT/usr/...)
# and the per-build workspace where ns-make-libs installs (inst-$HOST).
export CFLAGS="${CFLAGS:-} ${NS_OPT_CFLAGS} ${NS_HARDEN_CFLAGS} ${NS_TUNE_CFLAGS} \
    -I${SYSROOT}/usr/include -I$TARGET_WORKSPACE/inst-$HOST/include"
export CXXFLAGS="${CXXFLAGS:-} ${CFLAGS}"
export LDFLAGS="${LDFLAGS:-} ${NS_LDFLAGS_HARDEN} \
    -L${SYSROOT}/usr/lib -L$TARGET_WORKSPACE/inst-$HOST/lib"

# Restrict pkg-config to aarch64 locations only. The build host is amd64
# Debian, and without this we'd end up linking against the host's libs.
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig"

# For local development, you can clone any repository into target workspace
# before running this script.
ns-clone
ns-make-tools install
ns-make-libs install

cd $TARGET_WORKSPACE/netsurf/

# libevdev / pthread are picked up by the framebuffer frontend; -lm is needed
# explicitly by some new libs.
export LDFLAGS="$LDFLAGS -levdev -lpthread -lm"

export CC="${HOST}-gcc"
export STRIP="${HOST}-strip"
$MAKE TARGET=framebuffer NETSURF_FB_FONTLIB=freetype NETSURF_STRIP_BINARY=YES NETSURF_USE_LIBICONV_PLUG=NO NETSURF_USE_DUKTAPE=NO NETSURF_REMARKABLE=YES
