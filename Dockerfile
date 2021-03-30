FROM ghcr.io/toltec-dev/base:v2.0

RUN apt-get update -y \
    && apt-get install -y bison flex libexpat-dev libpng-dev libjpeg-dev git gperf libcurl3-dev automake

# Build curl 7.75.0 targeting armhf
RUN export DEBIAN_FRONTEND=noninteractive \
    && cd /root \
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
