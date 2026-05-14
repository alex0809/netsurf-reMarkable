#!/bin/sh

# Cross-compile the third-party dependencies required for netsurf,
# targeting reMarkable Paper Pro (aarch64, Cortex-A53).
#
# Notes:
#  * sha512sum is used for download verification (stronger than sha256).
#  * Downloads are forced over HTTPS with TLSv1.2 or higher.
#  * Build flags add stack-protector / FORTIFY_SOURCE hardening and tune
#    for Cortex-A53 (Paper Pro's i.MX 8M Mini SoC).
#
# Required environment (set by the Dockerfile):
#   CHOST    = aarch64-linux-gnu
#   SYSROOT  = isolated install prefix for our cross libs

set -eu

export DEBIAN_FRONTEND=noninteractive

# Sanity check.
: "${CHOST:?CHOST must be set (e.g. aarch64-linux-gnu)}"
: "${SYSROOT:?SYSROOT must be set (isolated install prefix)}"

# Curl flags reused for every download to enforce HTTPS-only + retries.
CURL_OPTS="--proto =https --tlsv1.2 --fail --silent --show-error --location \
    --retry 3 --retry-delay 5 --connect-timeout 20"

# Hardening + Cortex-A53 tuning. In aarch64 NEON and hard-float are
# mandatory (no -mfpu / -mfloat-abi flags).
HARDEN_CFLAGS="-fstack-protector-strong -D_FORTIFY_SOURCE=2 \
    -fno-plt -ffunction-sections -fdata-sections"
OPT_CFLAGS="-O2 -pipe -fomit-frame-pointer"
TUNE_CFLAGS="-march=armv8-a+crc -mtune=cortex-a53"
HARDEN_LDFLAGS="-Wl,-z,relro,-z,now -Wl,-z,noexecstack -Wl,--gc-sections"

export CC="${CHOST}-gcc"
export CXX="${CHOST}-g++"
export AR="${CHOST}-ar"
export STRIP="${CHOST}-strip"
export RANLIB="${CHOST}-ranlib"

export CFLAGS="${CFLAGS:-} ${OPT_CFLAGS} ${HARDEN_CFLAGS} ${TUNE_CFLAGS}"
export CXXFLAGS="${CXXFLAGS:-} ${CFLAGS}"
export LDFLAGS="${LDFLAGS:-} ${HARDEN_LDFLAGS}"

# Help configure scripts find the libs we install ourselves.
# Use PKG_CONFIG_LIBDIR (not _PATH) so pkg-config ONLY looks in aarch64
# locations — otherwise the build host's amd64 /usr/lib/pkgconfig would
# leak into the cross build.
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig"

verify_and_extract() {
    archive="$1"
    expected="$2"
    echo "${expected}  ${archive}" > sha512sums
    sha512sum -c sha512sums
    tar --strip-components=1 -xf "${archive}"
    rm "${archive}" sha512sums
}

# Build libiconv 1.17
(
    mkdir libiconv && cd libiconv
    curl ${CURL_OPTS} -o libiconv.tar.gz \
        "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz"
    verify_and_extract libiconv.tar.gz \
        "18a09de2d026da4f2d8b858517b0f26d853b21179cf4fa9a41070b2d140030ad9525637dc4f34fc7f27abca8acdc84c6751dfb1d426e78bf92af4040603ced86"
    ./configure --prefix="${SYSROOT}/usr" --host="${CHOST}" \
        --enable-static --disable-shared --disable-nls
    make
    make install
    cd .. && rm -rf libiconv
)

# Build OpenSSL 3.0.20 (LTS).
(
    mkdir openssl && cd openssl
    curl ${CURL_OPTS} -o openssl.tar.gz \
        "https://github.com/openssl/openssl/releases/download/openssl-3.0.20/openssl-3.0.20.tar.gz"
    verify_and_extract openssl.tar.gz \
        "3583a44bf9dec4deeade371d6861ce799821a85b32a4d9a8fcae253d78df8f93025ed73fb8efcaf23cc305b11d5aec439852444b3207d211f55660d1f89f5c9c"
    ./Configure no-shared no-comp no-tests \
        --prefix="${SYSROOT}/usr" --openssldir="${SYSROOT}/usr/ssl" \
        --cross-compile-prefix="${CHOST}-" \
        linux-aarch64
    make
    make install_sw
    cd .. && rm -rf openssl
)

# Build curl 8.20.0.
# --with-openssl picks up the freshly built OpenSSL via PKG_CONFIG_PATH.
(
    mkdir curl && cd curl
    curl ${CURL_OPTS} -o curl.tar.gz \
        "https://github.com/curl/curl/releases/download/curl-8_20_0/curl-8.20.0.tar.gz"
    verify_and_extract curl.tar.gz \
        "0d8798d854a32d86ec260fdfabbcf983521a56589d8e5963543a88119e57d231c4a5f3e64737cff61845d837684c73ef58eff92f9c921ef03d87c1d37531e6bf"
    ./configure --prefix="${SYSROOT}/usr" --host="${CHOST}" \
        --enable-static --disable-shared \
        --with-openssl --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
        --disable-ldap --disable-ldaps --disable-rtsp --disable-dict \
        --disable-telnet --disable-tftp --disable-pop3 --disable-imap \
        --disable-smb --disable-smtp --disable-gopher --disable-mqtt \
        --disable-manual --without-libpsl --without-libidn2 \
        --without-librtmp --without-zstd --without-brotli
    make
    make install
    cd .. && rm -rf curl
)

# Build FreeType 2.13.3 (fixes CVE-2022-27404/5/6 etc.).
# GitHub source archive lacks the dlg submodule; stub the files it expects
# so the make rules pass. dlg is only compiled when FT_DEBUG_LOGGING is in
# CFLAGS, which we never set.
(
    mkdir freetype && cd freetype
    curl ${CURL_OPTS} -o freetype.tar.gz \
        "https://codeload.github.com/freetype/freetype/tar.gz/refs/tags/VER-2-13-3"
    verify_and_extract freetype.tar.gz \
        "fccfaa15eb79a105981bf634df34ac9ddf1c53550ec0b334903a1b21f9f8bf5eb2b3f9476e554afa112a0fca58ec85ab212d674dfd853670efec876bacbe8a53"
    mkdir -p subprojects/dlg/include/dlg subprojects/dlg/src/dlg
    : > subprojects/dlg/include/dlg/dlg.h
    : > subprojects/dlg/include/dlg/output.h
    : > subprojects/dlg/src/dlg/dlg.c
    bash autogen.sh
    ./configure --prefix="${SYSROOT}/usr" --host="${CHOST}" \
        --enable-static=yes --enable-shared=no \
        --without-zlib --without-png --without-bzip2 --without-harfbuzz \
        --without-brotli
    make
    make install
    cd .. && rm -rf freetype
)

# Build libjpeg-turbo 3.0.4. Use an inline toolchain file because Debian
# doesn't ship a cmake toolchain file for our triplet by default.
(
    mkdir libjpeg-turbo && cd libjpeg-turbo
    curl ${CURL_OPTS} -o libjpeg-turbo.tar.gz \
        "https://codeload.github.com/libjpeg-turbo/libjpeg-turbo/tar.gz/refs/tags/3.0.4"
    verify_and_extract libjpeg-turbo.tar.gz \
        "f43e1b6b9d048e29e381796c71e1c34a04c0f1c52c1f462db9f9930cfc75d69a50861be2570a6a4adc26a4183b6601300fd9d5553c06bc042f0d32fc1e408ed9"
    cat > aarch64-toolchain.cmake <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER ${CHOST}-gcc)
set(CMAKE_CXX_COMPILER ${CHOST}-g++)
set(CMAKE_AR ${CHOST}-ar)
set(CMAKE_STRIP ${CHOST}-strip)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$(pwd)/aarch64-toolchain.cmake" \
        -DCMAKE_INSTALL_PREFIX="${SYSROOT}/usr" \
        -DENABLE_SHARED=FALSE -DENABLE_STATIC=TRUE \
        -DWITH_TURBOJPEG=FALSE
    make
    make install
    cd .. && rm -rf libjpeg-turbo
)
