FROM ghcr.io/toltec-dev/base:v3.1

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        automake \
        bison \
        ca-certificates \
        flex \
        git \
        gperf \
        libexpat-dev \
        libpng-dev \
        libtool \
    && rm -rf /var/lib/apt/lists/*

ADD scripts/install_dependencies.sh install_dependencies.sh

RUN ./install_dependencies.sh
