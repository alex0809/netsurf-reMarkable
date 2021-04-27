# NetSurf-reMarkable [![Build for reMarkable](https://github.com/alex0809/netsurf-reMarkable/actions/workflows/build.yml/badge.svg)](https://github.com/alex0809/netsurf-reMarkable/actions/workflows/build.yml)

NetSurf is a lightweight and portable open-source web browser. This project adapts NetSurf for the reMarkable E Ink tablet.
This repository contains the code for to building and releasing new versions.

## Installation

### opkg package

On the [releases page](https://github.com/alex0809/netsurf-reMarkable/releases), you can find the latest release.
The release assets contain a file `netsurf_[version]_rmall.ipk` that allows for easy installation on device, if you have
`opkg` configured on the device. 

You can find an installation script for `opkg` in the [Toltec](https://github.com/toltec-dev/toltec) repository.

Example commands to download and install the ipk file:
```
wget https://github.com/alex0809/netsurf-reMarkable/releases/download/vx.x/netsurf_0.x-x_rmall.ipk
scp netsurf_0.x-x_rmall.ipk root@10.11.99.1:
ssh root@remarkable opkg install netsurf_0.x-x_rmall.ipk
```

### Local build and installation

#### Requirements

The build itself is done in a Docker container, so apart from Docker and make, there
should be no additional requirements.

#### Commands

`make image` to build the Docker image with the toolchain, then `make build` to build netsurf.
The resulting netsurf binary is `build/netsurf/nsfb`.

> MacOS note:
> There is an [open issue](https://github.com/alex0809/netsurf-reMarkable/issues/21) with the build when using a bind-mounted build directory.
> A workaround will be automatically enabled when running `make build` under MacOS, please see the ticket for details.

### Installation

`make` prints a list of all available commands by default.

`make install` to build and then install the updated binary to the device.
This will use `scp` to copy the binary and required files to the device.
Device address used is by default `10.11.99.1` (i.e. reMarkable connected to your PC via USB), but can be overridden with the `INSTALL_DESTINATION` variable.
The netsurf binary will be copied to `/home/root/netsurf`, and the required resources are copied to `/home/root/.netsurf`.

`make uninstall` to remove the binary and other installed files from the device.

## Local development

`make local-dev` to set up the workspace for local development.
This will prepare the `build/` directory by cloning the latest version of all forked code repositories.

The build script (called when running `make build`) will only clone missing repositories,
so any local changes will be picked up with the next build.

## Related repositories

- [libhubbub-reMarkable](https://github.com/alex0809/libhubbub-reMarkable): fork of libhubbub which changes default encoding from Windows-1252 to UTF-8
- [libnsfb-reMarkable](https://github.com/alex0809/libnsfb-reMarkable): fork of libnsfb with reMarkable-specific code for drawing to the screen and input handling
- [netsurf-base-reMarkable](https://github.com/alex0809/netsurf-base-reMarkable): fork of netsurf, with modifications to make it work better on the reMarkable
