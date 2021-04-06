apt-get update -y 
apt-get install -y bison flex libexpat-dev libpng-dev git gperf automake libtool

# Build curl 7.75.0 targeting armhf
export DEBIAN_FRONTEND=noninteractive \
    && mkdir curl \
    && cd curl \
    && curl https://curl.se/download/curl-7.75.0.tar.gz -o curl.tar.gz \
    && echo "4d51346fe621624c3e4b9f86a8fd6f122a143820e17889f59c18f245d2d8e7a6  curl.tar.gz" > sha256sums \
    && sha256sum -c sha256sums \
    && tar --strip-components=1 -xf curl.tar.gz \
    && rm curl.tar.gz sha256sums \
    && ./configure --prefix=/usr --host="$CHOST" \
    && make \
    && DESTDIR="$SYSROOT" make install \
    && cd .. \
    && rm -rf curl \
    && find "$SYSROOT" -type l,f -name "*.la" | xargs --no-run-if-empty rm

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
    && rm -rf freetype \
    && find "$SYSROOT" -type l,f -name "*.la" | xargs --no-run-if-empty rm

cat > toolchain.cmake <<"EOF"
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_SYSROOT /opt/x-tools/arm-remarkable-linux-gnueabihf/arm-remarkable-linux-gnueabihf/sysroot)

set(tools /opt/x-tools/arm-remarkable-linux-gnueabihf)
set(CMAKE_C_COMPILER ${tools}/bin/arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER ${tools}/bin/arm-linux-gnueabihf-g++)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

# Build libjpeg-turbo 2.0.90 targeting armhf
export DEBIAN_FRONTEND=noninteractive \
    && mkdir libjpeg-turbo \
    && cd libjpeg-turbo \
    && curl "https://codeload.github.com/libjpeg-turbo/libjpeg-turbo/tar.gz/refs/tags/2.0.90" -o libjpeg-turbo.tar.gz \
    && echo "6a965adb02ad898b2ae48214244618fe342baea79db97157fdc70d8844ac6f09  libjpeg-turbo.tar.gz" > sha256sums \
    && sha256sum -c sha256sums \
    && tar --strip-components=1 -xf libjpeg-turbo.tar.gz \
    && rm libjpeg-turbo.tar.gz sha256sums \
    && cmake -DCMAKE_SYSROOT="$SYSROOT" -DCMAKE_TOOLCHAIN_FILE=../toolchain.cmake -DCMAKE_INSTALL_LIBDIR=$SYSROOT/lib -DCMAKE_INSTALL_INCLUDEDIR=$SYSROOT/usr/include \
    && make \
    && make install \
    && cd .. \
    && rm -rf libjpeg-turbo \
    && find "$SYSROOT" -type l,f -name "*.la" | xargs --no-run-if-empty rm
