# NetSurf-reMarkable [![Build for reMarkable](https://github.com/alex0809/netsurf-reMarkable/actions/workflows/build.yml/badge.svg)](https://github.com/alex0809/netsurf-reMarkable/actions/workflows/build.yml)[![rm1](https://img.shields.io/badge/rM1-supported-green)](https://remarkable.com/store/remarkable)[![rm2](https://img.shields.io/badge/rM2-supported-green)](https://remarkable.com/store/remarkable-2)[![opkg](https://img.shields.io/badge/OPKG-netsurf-blue)](https://toltec-dev.org/)

NetSurf is a lightweight and portable open-source web browser. This project adapts NetSurf for the reMarkable E Ink tablet.
This repository contains the code for to building and releasing new versions.

## Installation

### Toltec

You can install neturf with [Toltec](https://toltec-dev.org) using the following command:

```
opkg install netsurf
```

### Github Release

On the [releases page](https://github.com/alex0809/netsurf-reMarkable/releases), you can find the latest release.
The release assets contain a file `netsurf_[version]_rmall.ipk` that allows for easy installation on device.

Example commands to download and install the ipk file:
```
version=0.4
wget https://github.com/alex0809/netsurf-reMarkable/releases/download/v$version/netsurf_$version-1_rmall.ipk
scp netsurf_$version-1_rmall.ipk root@10.11.99.1:
ssh root@remarkable opkg install netsurf_$version-1_rmall.ipk
```

To install a different release change the `version=` line to the version number for the release you wish to install.

## Usage

The 'a' in the bottom-right corner screen toggles the keyboard.

More usage information may be found on the [official NetSurf website](https://www.netsurf-browser.org/documentation/#User).

### Local build and installation

#### Requirements

The build itself is done in a Docker container, so apart from Docker and make, there
should be no additional requirements.

`make` prints a list of all available commands by default.

#### Build

`make image` to build the Docker image with the toolchain, then `make build` to build netsurf.
The resulting netsurf binary is `build/netsurf/nsfb`.

> MacOS note:
> There is an [open issue](https://github.com/alex0809/netsurf-reMarkable/issues/21) with the build when using a bind-mounted build directory.
> A workaround will be automatically enabled when running `make build` under MacOS, please see the ticket for details.

#### Installation

`make install` to build and then install the updated binary to the device.
This will use `scp` to copy the binary and required files to the device.
Device address used is by default `10.11.99.1` (i.e. reMarkable connected to your PC via USB), but can be overridden with the `INSTALL_DESTINATION` variable.
The netsurf binary will be copied to `~/netsurf`, and the required resources are copied to `~/.netsurf`.

The font files defined in the configuration file `~/.netsurf/Choices` must exist.
You can either install the pre-configured fonts via opkg, or copy your own preferred fonts to the device and adapt the `Choices` file.

Installation of pre-configured fonts:
```
opkg install dejavu-fonts-ttf-DejaVuSans dejavu-fonts-ttf-DejaVuSans-Bold dejavu-fonts-ttf-DejaVuSans-BoldOblique dejavu-fonts-ttf-DejaVuSans-Oblique dejavu-fonts-ttf-DejaVuSerif dejavu-fonts-ttf-DejaVuSerif-Bold dejavu-fonts-ttf-DejaVuSerif-Italic dejavu-fonts-ttf-DejaVuSansMono dejavu-fonts-ttf-DejaVuSansMono-Bold
```

`make uninstall` to remove the binary and other installed files from the device.

## Local development

`make checkout` to set up the workspace for local development.
This will prepare the `build/` directory by cloning the HEAD of all forked code repositories.

The build script (called when running `make build`) will only clone missing repositories,
so any local changes will be picked up with the next build.

To use clangd language server, you can run `make clangd-build`, which will prepare a Docker container
clangd and compile-commands set up.
After the build is complete, you can can start the container with `make clangd-start`, and access with
[clangd_docker.sh](scripts/clangd_docker.sh).

## Related repositories

- [libnsfb-reMarkable](https://github.com/alex0809/libnsfb-reMarkable): fork of libnsfb with reMarkable-specific code for drawing to the screen and input handling
- [netsurf-base-reMarkable](https://github.com/alex0809/netsurf-base-reMarkable): fork of netsurf, with modifications to make it work better on the reMarkable
