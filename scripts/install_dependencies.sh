#!/bin/sh

# This script installs and cross-compiles the dependencies required for netsurf build.
# To be run during the Dockerfile build.

# Build openssl targeting armhf
export DEBIAN_FRONTEND=noninteractive \
    && mkdir openssl \
    && cd openssl \
    && curl https://www.openssl.org/source/openssl-1.1.1k.tar.gz -o openssl.tar.gz \
    && echo "892a0875b9872acd04a9fde79b1f943075d5ea162415de3047c327df33fbaee5  openssl.tar.gz" > sha256sums \
    && sha256sum -c sha256sums \
    && tar --strip-components=1 -xf openssl.tar.gz \
    && rm openssl.tar.gz sha256sums \
    && ./Configure no-shared no-comp --prefix=$SYSROOT/usr --openssldir=$SYSROOT/usr --cross-compile-prefix=$CHOST- linux-armv4 \
    && make \
    && DESTDIR="$SYSROOT" make install \
    && cd .. \
    && rm -rf openssl || exit 1

# Build curl 7.75.0 targeting armhf
export DEBIAN_FRONTEND=noninteractive \
    && mkdir curl \
    && cd curl \
    && curl https://curl.se/download/curl-7.75.0.tar.gz -o curl.tar.gz \
    && echo "4d51346fe621624c3e4b9f86a8fd6f122a143820e17889f59c18f245d2d8e7a6  curl.tar.gz" > sha256sums \
    && sha256sum -c sha256sums \
    && tar --strip-components=1 -xf curl.tar.gz \
    && rm curl.tar.gz sha256sums \
    && ./configure --prefix=/usr --host="$CHOST" --enable-static --disable-shared --with-openssl --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
    && make \
    && DESTDIR="$SYSROOT" make install \
    && cd .. \
    && rm -rf curl || exit 1

# Build FreeType 2.10.4 targeting armhf
export DEBIAN_FRONTEND=noninteractive \
    && mkdir freetype \
    && cd freetype \
    && curl "https://gitlab.freedesktop.org/freetype/freetype/-/archive/VER-2-10-4/freetype-VER-2-10-4.tar.gz" -o freetype.tar.gz \
    && echo "4d47fca95debf8eebde5d27e93181f05b4758701ab5ce3e7b3c54b937e8f0962  freetype.tar.gz" > sha256sums \
    && sha256sum -c sha256sums \
    && tar --strip-components=1 -xf freetype.tar.gz \
    && rm freetype.tar.gz sha256sums \
    && bash autogen.sh \
    && ./configure --without-zlib --without-png --enable-static=yes --enable-shared=no --without-bzip2 --host=arm-linux-gnueabihf --host="$CHOST" --disable-freetype-config \
    && make \
    && DESTDIR="$SYSROOT" make install \
    && cd .. \
    && rm -rf freetype || exit 1

# Build libjpeg-turbo 2.0.90 targeting armhf
export DEBIAN_FRONTEND=noninteractive \
    && mkdir libjpeg-turbo \
    && cd libjpeg-turbo \
    && curl "https://codeload.github.com/libjpeg-turbo/libjpeg-turbo/tar.gz/refs/tags/2.0.90" -o libjpeg-turbo.tar.gz \
    && echo "6a965adb02ad898b2ae48214244618fe342baea79db97157fdc70d8844ac6f09  libjpeg-turbo.tar.gz" > sha256sums \
    && sha256sum -c sha256sums \
    && tar --strip-components=1 -xf libjpeg-turbo.tar.gz \
    && rm libjpeg-turbo.tar.gz sha256sums \
    && cmake -DCMAKE_SYSROOT="$SYSROOT" -DCMAKE_TOOLCHAIN_FILE=/usr/share/cmake/$CHOST.cmake -DCMAKE_INSTALL_LIBDIR=$SYSROOT/lib -DCMAKE_INSTALL_INCLUDEDIR=$SYSROOT/usr/include -DENABLE_SHARED=FALSE \
    && make \
    && make install \
    && cd .. \
    && rm -rf libjpeg-turbo || exit 1
