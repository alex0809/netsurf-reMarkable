# Build image for cross-compiling NetSurf to reMarkable Paper Pro (aarch64).
#
# Original Toltec base image was armhf-only (built for rM1/rM2). The Paper
# Pro runs a 64-bit kernel/userspace, so we switch to a clean Debian and
# install Debian's official aarch64 cross toolchain. Debian multiarch is
# enabled for arm64 so we can pull libexpat/libpng/zlib dev headers and
# libs that match the cross target.

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Cross triplet, isolated sysroot for libs we build ourselves.
ENV CHOST=aarch64-linux-gnu
ENV SYSROOT=/opt/aarch64-rmpp
ENV PKG_CONFIG_PATH="${SYSROOT}/usr/lib/pkgconfig"

RUN dpkg --add-architecture arm64 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        # Host build essentials (for nsgenbind and other native tools
        # that NetSurf needs running on the build machine itself)
        build-essential \
        # aarch64 cross toolchain
        gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
        binutils-aarch64-linux-gnu \
        libc6-dev-arm64-cross \
        # arm64 system libs that the third-party deps and the netsurf
        # frontend / libnsfb backend pull in. libevdev+libudev power the
        # framebuffer surface's input loop; libuuid is used by
        # remarkable_xochitl_import.c to mint xochitl document UUIDs.
        libexpat1-dev:arm64 libpng-dev:arm64 zlib1g-dev:arm64 \
        libevdev-dev:arm64 libudev-dev:arm64 uuid-dev:arm64 \
        # Autotools + cmake
        autoconf automake libtool \
        bison flex gperf \
        cmake make \
        pkg-config \
        # Misc
        ca-certificates curl git \
    && rm -rf /var/lib/apt/lists/*

# Pre-create the isolated sysroot so cross-libs land there cleanly.
RUN mkdir -p "${SYSROOT}/usr/lib" "${SYSROOT}/usr/include"

ADD scripts/install_dependencies.sh install_dependencies.sh

RUN ./install_dependencies.sh
