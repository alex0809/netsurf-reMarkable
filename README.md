# NetSurf-reMarkable

This repository contains a script that builds NetSurf for the reMarkable.

The actual NetSurf source code is fully downloaded during the build. 
For details, you can look at the [env.sh](https://github.com/netsurf-browser/netsurf/blob/master/docs/env.sh) file that is downloaded during the build.

## Installing on the device

Each release contains the `nsfb` binary and a required `resources` folder.

The contents of the `resources` should be copied to any of these locations:
- `/usr/share/netsurf/`
- `$NETSURFRES/`
- `~/.netsurf/`

## Building locally

```
docker-compose up -d
```
