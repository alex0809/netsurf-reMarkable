FROM ghcr.io/toltec-dev/base:v1.5

ADD scripts/install_dependencies.sh install_dependencies.sh

RUN ./install_dependencies.sh
