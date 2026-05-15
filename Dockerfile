# Build image for cross-compiling NetSurf to reMarkable Paper Pro (aarch64).
#
# Original Toltec base image was armhf-only (built for rM1/rM2). The Paper
# Pro runs a 64-bit kernel/userspace, so we switch to a clean Debian and
# install Debian's official aarch64 cross toolchain. Debian multiarch is
# enabled for arm64 so we can pull libexpat/libpng/zlib dev headers and
# libs that match the cross target.
#
# Package roles, since we can't comment inside RUN:
#   build-essential, autoconf, automake, libtool, bison, flex, gperf,
#   cmake, make, pkg-config        -- host build tools (also used to run
#                                     nsgenbind during the netsurf build)
#   gcc-aarch64-linux-gnu, g++-... -- aarch64 cross toolchain
#   binutils-aarch64-linux-gnu     -- aarch64 binutils
#   libc6-dev-arm64-cross          -- aarch64 libc headers/libs
#   libexpat1-dev:arm64            -- needed by libsvgtiny (and netsurf XML)
#   libpng-dev:arm64               -- PNG image support in netsurf
#   zlib1g-dev:arm64               -- common transitive dep
#   libevdev-dev:arm64             -- libnsfb input layer (kept for build,
#                                     final binary uses raw evdev syscalls
#                                     via the Paper Pro DRM patches)
#   libudev-dev:arm64              -- libnsfb input device discovery
#   uuid-dev:arm64                 -- remarkable_xochitl_import.c uuids
#   libdrm-dev:arm64               -- DRM/KMS surface backend (paperpro)
#   ca-certificates, curl, git     -- downloading sources

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

ENV CHOST=aarch64-linux-gnu
ENV SYSROOT=/opt/aarch64-rmpp
ENV PKG_CONFIG_PATH="${SYSROOT}/usr/lib/pkgconfig"

RUN dpkg --add-architecture arm64 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        gcc-aarch64-linux-gnu \
        g++-aarch64-linux-gnu \
        binutils-aarch64-linux-gnu \
        libc6-dev-arm64-cross \
        libexpat1-dev:arm64 \
        libpng-dev:arm64 \
        zlib1g-dev:arm64 \
        libevdev-dev:arm64 \
        libudev-dev:arm64 \
        uuid-dev:arm64 \
        libdrm-dev:arm64 \
        autoconf \
        automake \
        libtool \
        bison \
        flex \
        gperf \
        cmake \
        make \
        pkg-config \
        ca-certificates \
        curl \
        git \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${SYSROOT}/usr/lib" "${SYSROOT}/usr/include"

ADD scripts/install_dependencies.sh install_dependencies.sh

RUN ./install_dependencies.sh
