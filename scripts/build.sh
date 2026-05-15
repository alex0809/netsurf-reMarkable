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
# /usr/include/libdrm is added so libnsfb's DRM surface backend finds
# <xf86drm.h> / <xf86drmMode.h> from libdrm-dev:arm64.
export CFLAGS="${CFLAGS:-} ${NS_OPT_CFLAGS} ${NS_HARDEN_CFLAGS} ${NS_TUNE_CFLAGS} \
    -I${SYSROOT}/usr/include -I$TARGET_WORKSPACE/inst-$HOST/include \
    -I/usr/include/libdrm"
export CXXFLAGS="${CXXFLAGS:-} ${CFLAGS}"
export LDFLAGS="${LDFLAGS:-} ${NS_LDFLAGS_HARDEN} \
    -L${SYSROOT}/usr/lib -L$TARGET_WORKSPACE/inst-$HOST/lib"

# Restrict pkg-config to aarch64 locations only. The build host is amd64
# Debian, and without this we'd end up linking against the host's libs.
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig"

# Also export VARIANT=release so libnsfb (and other NetSurf libs that
# follow the same convention) drop -Werror. See the longer comment near
# the final $MAKE invocation for rationale.
export VARIANT=release

# For local development, you can clone any repository into target workspace
# before running this script.
ns-clone

# Drop the rM1/rM2 mxcfb surface backend into a DRM/KMS one for the
# Paper Pro. The patch is idempotent (sentinel-guarded).
PATCH_ROOT="/opt/netsurf/patches/paperpro-drm-surface"
if [ -d "$PATCH_ROOT" ] && [ -d "$TARGET_WORKSPACE/libnsfb" ]; then
    sh "$PATCH_ROOT/apply.sh" "$PATCH_ROOT" "$TARGET_WORKSPACE/libnsfb"
fi

ns-make-tools install
ns-make-libs install

cd $TARGET_WORKSPACE/netsurf/

# Final-link libs:
#   -ldrm       : DRM/KMS surface backend
#   -luuid      : remarkable_xochitl_import.c
#   -ludev      : still needed because xochitl_import.c uses
#                 udev_device_* helpers? — kept for safety, drops out
#                 cleanly if unused thanks to ld --gc-sections
#   -lpthread, -lm : standard
# Note: NO -levdev. Our patched input.c uses raw evdev syscalls so the
# binary does not pull libevdev.so.2 (which is absent on the rMPP).
export LDFLAGS="$LDFLAGS -ldrm -luuid -ludev -lpthread -lm"

export CC="${HOST}-gcc"
export STRIP="${HOST}-strip"

# VARIANT=release disables libnsfb's -Werror. Our hardening CFLAGS combined
# with aarch64-specific warning patterns (stricter -Wcast-align in
# particular) can trip warnings that the original armhf build never saw.
# We want to ship, not chase pedantic warnings in third-party code we
# don't own.
$MAKE TARGET=framebuffer \
    NETSURF_FB_FONTLIB=freetype \
    NETSURF_STRIP_BINARY=YES \
    NETSURF_USE_LIBICONV_PLUG=NO \
    NETSURF_USE_DUKTAPE=NO \
    NETSURF_REMARKABLE=YES \
    VARIANT=release
