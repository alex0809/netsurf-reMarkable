#!/bin/bash

SCRIPTPATH=/opt/netsurf/scripts
if [ ! -f $SCRIPTPATH/env.sh ]; then
    echo "env.sh doesn't exist, downloading latest..."
    curl "https://raw.githubusercontent.com/netsurf-browser/netsurf/master/docs/env.sh" -o $SCRIPTPATH/env.sh
fi

TARGET_WORKSPACE=/opt/netsurf/build
HOST=arm-remarkable-linux-gnueabihf

source $SCRIPTPATH/env.sh

# Required so the netsurf make picks up the previously built libraries
export CFLAGS="$CFLAGS -I$TARGET_WORKSPACE/inst-$HOST/include"
export LDFLAGS="$LDFLAGS -L$TARGET_WORKSPACE/inst-$HOST/lib" 
# freetype libs end up in /usr/local, so include that for pkg-config
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$SYSROOT/usr/local/lib/pkgconfig"

# For local development: if $LIBNSFB_LOCATION is set, use that instead of checking out from github
if [ -z ${LIBNSFB_LOCATION+x} ]; then
    echo "Cloning fork of libnsfb"
    git clone https://github.com/alex0809/libnsfb-reMarkable.git $TARGET_WORKSPACE/libnsfb
else
    echo "LIBNSFB_LOCATION is set, copying into workspace"
    rm -rf $TARGET_WORKSPACE/libnsfb
    cp -r $LIBNSFB_LOCATION $TARGET_WORKSPACE/libnsfb
fi

ns-clone
ns-pull-install

cd $TARGET_WORKSPACE/netsurf/

# Would probably be nicer to to pkg_config libevdev in the netsurf Makefile,
# but we are re-pulling that Makefile every build.
# This works for now.
export LDFLAGS="$LDFLAGS -levdev -lpthread"

export BUILD_CC="arm-remarkable-linux-gnueabihf-gcc"
make TARGET=framebuffer NETSURF_FB_FONTLIB=freetype CC=$BUILD_CC
