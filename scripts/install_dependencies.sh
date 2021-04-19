#!/bin/sh

# This script installs and cross-compiles the dependencies required for netsurf build.
# To be run during the Dockerfile build.

apt-get update -y 
apt-get install -y bison flex git gperf automake libtool libpng-dev

# Build curl 7.75.0 targeting armhf
export DEBIAN_FRONTEND=noninteractive \
    && mkdir curl \
    && cd curl \
    && curl https://curl.se/download/curl-7.75.0.tar.gz -o curl.tar.gz \
    && echo "4d51346fe621624c3e4b9f86a8fd6f122a143820e17889f59c18f245d2d8e7a6  curl.tar.gz" > sha256sums \
    && sha256sum -c sha256sums \
    && tar --strip-components=1 -xf curl.tar.gz \
    && rm curl.tar.gz sha256sums \
    && ./configure --prefix=/opt --host="$CHOST" \
    && make \
    && DESTDIR="$SYSROOT" make install \
    && cd .. \
    && rm -rf curl

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
    && ./configure --without-zlib --without-png --enable-static=yes --enable-shared=yes --without-bzip2 --host=arm-linux-gnueabihf --host="$CHOST" --disable-freetype-config --prefix=/opt \
    && make \
    && DESTDIR="$SYSROOT" make install \
    && cd .. \
    && rm -rf freetype

# Build libjpeg-turbo 2.0.90 targeting armhf
export DEBIAN_FRONTEND=noninteractive \
    && mkdir libjpeg-turbo \
    && cd libjpeg-turbo \
    && curl -L "https://sourceforge.net/projects/libjpeg-turbo/files/2.0.6/libjpeg-turbo-2.0.6.tar.gz" -o libjpeg-turbo.tar.gz \
    && echo "d74b92ac33b0e3657123ddcf6728788c90dc84dcb6a52013d758af3c4af481bb  libjpeg-turbo.tar.gz" > sha256sums \
    && sha256sum -c sha256sums \
    && tar --strip-components=1 -xf libjpeg-turbo.tar.gz \
    && rm libjpeg-turbo.tar.gz sha256sums \
    && cmake -DCMAKE_SYSROOT="$SYSROOT" -DCMAKE_TOOLCHAIN_FILE=/usr/share/cmake/$CHOST.cmake -DCMAKE_INSTALL_LIBDIR=/opt/lib -DCMAKE_INSTALL_INCLUDEDIR=/opt/include \
    && make \
    && DESTDIR="$SYSROOT" make install \
    && cd .. \
    && rm -rf libjpeg-turbo
