#!/bin/sh
# Pre-flight check to run BEFORE building / deploying nsfb to a Paper Pro.
# Usage on your dev machine, with the tablet connected over USB:
#   ssh root@10.11.99.1 'bash -s' < scripts/preflight_paperpro.sh
# or copy/paste the commands below into an SSH session on the tablet.

set -u

echo "=== Architecture =="
echo -n "  uname -m       : "; uname -m
echo -n "  getconf LONG_BIT: "; getconf LONG_BIT
echo -n "  binary loader  : "
# the dynamic loader path our build will bake into the ELF
[ -f /lib/ld-linux-aarch64.so.1 ] && echo "/lib/ld-linux-aarch64.so.1  OK" \
    || echo "MISSING — binary will fail with 'No such file'"

echo "=== glibc =="
echo -n "  ldd --version  : "; ldd --version 2>/dev/null | head -1
echo -n "  libc.so.6 -V   : "
/lib/aarch64-linux-gnu/libc.so.6 2>/dev/null | head -1 \
    || /lib/ld-linux-aarch64.so.1 --help 2>/dev/null | head -1 \
    || echo "(could not query libc directly)"
echo "  -> Build host uses Debian Bookworm glibc 2.36. If the tablet"
echo "     reports a version >= 2.36, the binary runs. If older, you"
echo "     will see 'GLIBC_2.36 not found' at startup."

echo "=== Required shared libraries =="
for lib in \
    libexpat.so.1 \
    libpng16.so.16 \
    libz.so.1 \
    libevdev.so.2 \
    libudev.so.1 \
    libuuid.so.1 \
    libpthread.so.0 \
    libm.so.6
do
    found=""
    for dir in /lib /lib/aarch64-linux-gnu /usr/lib /usr/lib/aarch64-linux-gnu; do
        [ -e "$dir/$lib" ] && { found="$dir/$lib"; break; }
    done
    if [ -n "$found" ]; then
        printf "  %-22s OK   %s\n" "$lib" "$found"
    else
        printf "  %-22s MISSING\n" "$lib"
    fi
done

echo "=== Framebuffer =="
ls -la /dev/fb* 2>/dev/null || echo "  no /dev/fb*"
ls -la /dev/dri/* 2>/dev/null
if [ -e /sys/class/graphics/fb0 ]; then
    echo -n "  fb0 size      : "; cat /sys/class/graphics/fb0/virtual_size 2>/dev/null
    echo -n "  fb0 bpp       : "; cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null
    echo -n "  fb0 name      : "; cat /sys/class/graphics/fb0/name 2>/dev/null
fi

echo "=== Input devices =="
ls /dev/input/event* 2>/dev/null
[ -f /proc/bus/input/devices ] && grep -E '^N:|^H:' /proc/bus/input/devices | head -10

echo "=== EPDC driver hint =="
dmesg 2>/dev/null | grep -iE 'epdc|eink|mxc' | head -5 \
    || echo "  (dmesg restricted)"
lsmod 2>/dev/null | grep -iE 'epdc|eink|mxc' | head -5

echo "=== Free space =="
df -h /home/root 2>/dev/null | tail -1
echo "=== Memory =="
free -m 2>/dev/null | head -2

echo
echo "=== Verdict =="
echo "If all lines above show OK / valid values, the build artefact"
echo "should at least START on this tablet. Display correctness still"
echo "depends on the EPDC driver compatibility (see"
echo "PAPER_PRO_FRAMEBUFFER_NOTES.md)."
