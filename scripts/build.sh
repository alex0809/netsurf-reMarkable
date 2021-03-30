#!/bin/bash

SCRIPTPATH=/opt/netsurf/scripts
if [ ! -f $SCRIPTPATH/env.sh ]; then
  echo "env.sh doesn't exist, downloading latest..."
  curl "https://raw.githubusercontent.com/netsurf-browser/netsurf/master/docs/env.sh" -o $SCRIPTPATH/env.sh
fi
exit

TARGET_WORKSPACE=/opt/netsurf/build
HOST=arm-remarkable-linux-gnueabihf

source $SCRIPTPATH/env.sh

export CFLAGS="$CFLAGS -I$TARGET_WORKSPACE/inst-$HOST/include"
export LDFLAGS="$LDFLAGS -L$TARGET_WORKSPACE/inst-$HOST/lib" 

ns-clone
ns-pull-install

cd $TARGET_WORKSPACE/netsurf/
export BUILD_CC="arm-remarkable-linux-gnueabihf-gcc"
make TARGET=framebuffer NETSURF_USE_JPEG=NO CC=$BUILD_CC 
