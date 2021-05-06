FROM ghcr.io/toltec-dev/base:v1.6

RUN apt-get update -y && apt-get install -y bison flex libexpat-dev libpng-dev git gperf automake libtool

ADD scripts/install_dependencies.sh install_dependencies.sh

RUN ./install_dependencies.sh

RUN ln -s /usr/bin/which /bin/which
