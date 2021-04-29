FROM ghcr.io/toltec-dev/base:v1.6

ADD scripts/install_dependencies.sh install_dependencies.sh

RUN ./install_dependencies.sh

RUN ln -s /usr/bin/which /bin/which
