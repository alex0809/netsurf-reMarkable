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

echo "Cloning fork of libnsfb"
git clone https://github.com/alex0809/libnsfb-reMarkable.git $TARGET_WORKSPACE/libnsfb

ns-clone
ns-pull-install

cd $TARGET_WORKSPACE/netsurf/
export BUILD_CC="arm-remarkable-linux-gnueabihf-gcc"
make TARGET=framebuffer NETSURF_FB_FONTLIB=freetype CC=$BUILD_CC
