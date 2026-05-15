#!/bin/sh
# Apply Paper Pro DRM surface patches to a fresh libnsfb-reMarkable clone.
# Invoked by scripts/build.sh after ns-clone.
#
# Usage:
#   apply.sh <path-to-patch-dir> <path-to-libnsfb-clone>

set -eu

PATCH_DIR="$1"
LIBNSFB_DIR="$2"

if [ ! -d "$PATCH_DIR" ]; then
    echo "apply.sh: patch source dir not found: $PATCH_DIR" >&2
    exit 1
fi

REMARKABLE_DIR="$LIBNSFB_DIR/src/surface/remarkable"
if [ ! -d "$REMARKABLE_DIR" ]; then
    echo "apply.sh: $REMARKABLE_DIR not found — wrong libnsfb tree?" >&2
    exit 1
fi

# Detect previous apply on the same workspace via a sentinel.
SENTINEL="$LIBNSFB_DIR/.paperpro-drm-applied"
if [ -f "$SENTINEL" ]; then
    echo "apply.sh: patches already applied at $LIBNSFB_DIR (sentinel exists)"
    exit 0
fi

echo "apply.sh: installing DRM/KMS surface + raw-evdev input"
for f in screen.h screen.c input.h input.c; do
    cp -f "$PATCH_DIR/$f" "$REMARKABLE_DIR/$f"
done

# Drop the libevdev pkg-config dependency from libnsfb's top Makefile —
# our new input.c uses raw evdev syscalls, so we don't want -levdev to
# leak into the final link command (libevdev.so.2 isn't on the rMPP).
if grep -q 'pkg_config_package_add_flags,libevdev' "$LIBNSFB_DIR/Makefile"; then
    sed -i '/pkg_config_package_add_flags,libevdev/d' "$LIBNSFB_DIR/Makefile"
    echo "apply.sh: stripped libevdev pkg-config from libnsfb Makefile"
fi

touch "$SENTINEL"
echo "apply.sh: done"
