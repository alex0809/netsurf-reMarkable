#!/bin/sh

# Cross-compile the third-party dependencies required for netsurf.
#
# Notes:
#  * sha512sum is used for download verification (stronger than sha256).
#  * Downloads are forced over HTTPS with TLSv1.2 or higher.
#  * Build flags add stack-protector / FORTIFY_SOURCE hardening and
#    a Cortex-A53-friendly tune (works on rMPP, gracefully ignored on
#    older ARMv7 toolchains that don't recognise armv8-a in AArch32 mode).

set -eu

export DEBIAN_FRONTEND=noninteractive

# Curl flags reused for every download to enforce HTTPS-only + retries.
CURL_OPTS="--proto =https --tlsv1.2 --fail --silent --show-error --location \
    --retry 3 --retry-delay 5 --connect-timeout 20"

# Hardening + Cortex-A53 tuning. Toolchain GCC may not all understand every
# flag; the script keeps going if a flag is silently ignored, but a hard
# failure aborts the build (set -e).
HARDEN_CFLAGS="-fstack-protector-strong -D_FORTIFY_SOURCE=2 \
    -fno-plt -ffunction-sections -fdata-sections"
OPT_CFLAGS="-O2 -pipe -fomit-frame-pointer"
TUNE_CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard -mtune=cortex-a53"
HARDEN_LDFLAGS="-Wl,-z,relro,-z,now -Wl,-z,noexecstack -Wl,--gc-sections \
    -Wl,--as-needed"

export CFLAGS="${CFLAGS:-} ${OPT_CFLAGS} ${HARDEN_CFLAGS} ${TUNE_CFLAGS}"
export CXXFLAGS="${CXXFLAGS:-} ${CFLAGS}"
export LDFLAGS="${LDFLAGS:-} ${HARDEN_LDFLAGS}"

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
    ./configure --prefix=$SYSROOT/usr --host="$CHOST" \
        --enable-static --disable-shared --disable-nls
    make
    make install
    cd .. && rm -rf libiconv
)

# Build OpenSSL 3.0.20 (LTS, replaces EOL 1.1.1k).
# Static, no-shared, no-comp; install_sw skips docs and FIPS module to
# save space and build time on the cross toolchain.
(
    mkdir openssl && cd openssl
    curl ${CURL_OPTS} -o openssl.tar.gz \
        "https://github.com/openssl/openssl/releases/download/openssl-3.0.20/openssl-3.0.20.tar.gz"
    verify_and_extract openssl.tar.gz \
        "3583a44bf9dec4deeade371d6861ce799821a85b32a4d9a8fcae253d78df8f93025ed73fb8efcaf23cc305b11d5aec439852444b3207d211f55660d1f89f5c9c"
    # Toltec base v3.1 ships an older libssl 1.x in the cross sysroot.
    # Wipe it before configuring/installing so curl 8.x doesn't pick up
    # stale headers/.pc files alongside the new 3.0.20 build.
    rm -rf "$SYSROOT/usr/include/openssl"
    rm -f "$SYSROOT/usr/lib/libssl."* "$SYSROOT/usr/lib/libcrypto."*
    rm -f "$SYSROOT/usr/lib/pkgconfig/openssl.pc" \
          "$SYSROOT/usr/lib/pkgconfig/libssl.pc" \
          "$SYSROOT/usr/lib/pkgconfig/libcrypto.pc"
    # DESTDIR doesn't reliably propagate through OpenSSL 3.x's sub-make
    # invocations under this cross toolchain, so we install directly into
    # the sysroot via an absolute --prefix and no DESTDIR.
    ./Configure no-shared no-comp no-tests \
        --prefix="$SYSROOT/usr" --openssldir="$SYSROOT/usr/ssl" \
        --cross-compile-prefix=$CHOST- \
        linux-armv4
    make
    make install_sw
    cd .. && rm -rf openssl
)

# Build curl 8.20.0 (replaces 7.75.0).
# --with-openssl picks up the freshly built OpenSSL in $SYSROOT.
(
    mkdir curl && cd curl
    curl ${CURL_OPTS} -o curl.tar.gz \
        "https://github.com/curl/curl/releases/download/curl-8_20_0/curl-8.20.0.tar.gz"
    verify_and_extract curl.tar.gz \
        "0d8798d854a32d86ec260fdfabbcf983521a56589d8e5963543a88119e57d231c4a5f3e64737cff61845d837684c73ef58eff92f9c921ef03d87c1d37531e6bf"
    # Drop the toltec base image's prebuilt libcurl shared lib so the final
    # nsfb link picks our libcurl.a (which is linked against OpenSSL 3) and
    # not the old libcurl.so (linked against OpenSSL 1.1, whose symbols are
    # no longer in the sysroot).
    rm -f "$SYSROOT/usr/lib/libcurl."* \
          "$SYSROOT/usr/lib/pkgconfig/libcurl.pc"
    ./configure --prefix=/usr --host="$CHOST" \
        --enable-static --disable-shared \
        --with-openssl --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt \
        --disable-ldap --disable-ldaps --disable-rtsp --disable-dict \
        --disable-telnet --disable-tftp --disable-pop3 --disable-imap \
        --disable-smb --disable-smtp --disable-gopher --disable-mqtt \
        --disable-manual --without-libpsl --without-libidn2 \
        --without-librtmp --without-zstd --without-brotli
    make
    DESTDIR="$SYSROOT" make install
    cd .. && rm -rf curl
)

# Build FreeType 2.13.3 (replaces 2.10.4, fixes CVE-2022-2740{4,5,6} etc.).
# Pulled from the official GitHub mirror to keep checksum control on one host.
(
    mkdir freetype && cd freetype
    curl ${CURL_OPTS} -o freetype.tar.gz \
        "https://codeload.github.com/freetype/freetype/tar.gz/refs/tags/VER-2-13-3"
    verify_and_extract freetype.tar.gz \
        "fccfaa15eb79a105981bf634df34ac9ddf1c53550ec0b334903a1b21f9f8bf5eb2b3f9476e554afa112a0fca58ec85ab212d674dfd853670efec876bacbe8a53"
    # The GitHub source archive doesn't carry the dlg submodule. Freetype's
    # toplevel make has two rules that touch it: check_out_submodule (runs
    # `git submodule update --init`) and copy_submodule (cp's specific
    # header/source files into src/dlg and include/dlg). Both fail on a
    # tarball checkout. dlg is only compiled when FT_DEBUG_LOGGING is in
    # CFLAGS, which we never set, so empty stubs at the expected paths
    # let both rules succeed without affecting the produced libfreetype.a.
    mkdir -p subprojects/dlg/include/dlg subprojects/dlg/src/dlg
    : > subprojects/dlg/include/dlg/dlg.h
    : > subprojects/dlg/include/dlg/output.h
    : > subprojects/dlg/src/dlg/dlg.c
    bash autogen.sh
    ./configure --host="$CHOST" \
        --enable-static=yes --enable-shared=no \
        --without-zlib --without-png --without-bzip2 --without-harfbuzz \
        --without-brotli
    make
    DESTDIR="$SYSROOT" make install
    cd .. && rm -rf freetype
)

# Build libjpeg-turbo 3.0.4 (replaces 2.0.90).
(
    mkdir libjpeg-turbo && cd libjpeg-turbo
    curl ${CURL_OPTS} -o libjpeg-turbo.tar.gz \
        "https://codeload.github.com/libjpeg-turbo/libjpeg-turbo/tar.gz/refs/tags/3.0.4"
    verify_and_extract libjpeg-turbo.tar.gz \
        "f43e1b6b9d048e29e381796c71e1c34a04c0f1c52c1f462db9f9930cfc75d69a50861be2570a6a4adc26a4183b6601300fd9d5553c06bc042f0d32fc1e408ed9"
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSROOT="$SYSROOT" \
        -DCMAKE_TOOLCHAIN_FILE=/usr/share/cmake/$CHOST.cmake \
        -DCMAKE_INSTALL_LIBDIR=$SYSROOT/lib \
        -DCMAKE_INSTALL_INCLUDEDIR=$SYSROOT/usr/include \
        -DENABLE_SHARED=FALSE -DENABLE_STATIC=TRUE \
        -DWITH_TURBOJPEG=FALSE
    make
    make install
    cd .. && rm -rf libjpeg-turbo
)
