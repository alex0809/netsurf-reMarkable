#!/bin/sh
# Pre-flight check to run BEFORE building / deploying nsfb on a Paper Pro.
# Works against the BusyBox userland that ships on rMPP (no GNU coreutils,
# no `head -N`, no `getconf`, etc.).
#
# Usage:
#   ssh root@10.11.99.1 'sh -s' < scripts/preflight_paperpro.sh

# Portable first-line: avoids `head -1` which busybox refuses.
first_line() {
    awk 'NR==1' 2>/dev/null
}
first_n() {
    n=$1
    awk -v n="$n" 'NR<=n' 2>/dev/null
}

echo "=== Architecture =="
echo "  uname -a       :"
uname -a
echo
echo "=== OS =="
[ -r /etc/os-release ] && cat /etc/os-release | first_n 6
echo
echo "=== Kernel =="
cat /proc/version 2>/dev/null | first_line
echo
echo "=== Loader =="
if [ -f /lib/ld-linux-aarch64.so.1 ]; then
    echo "  /lib/ld-linux-aarch64.so.1 PRESENT"
    ls -l /lib/ld-linux-aarch64.so.1
elif [ -f /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 ]; then
    echo "  /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 PRESENT"
else
    echo "  ld-linux-aarch64.so.1 MISSING — Debian-built binaries can't start"
fi

echo
echo "=== glibc =="
echo "  ldd --version  :"
ldd --version 2>&1 | first_n 2
echo "  /lib/libc.so.6 banner (raw bytes search for 'GLIBC' / 'glibc'):"
strings /lib/libc.so.6 2>/dev/null | grep -iE '^GNU C Library|glibc [0-9]|stable release version' | first_n 3
echo "  symbol versions defined in libc:"
strings /lib/libc.so.6 2>/dev/null \
    | grep -oE 'GLIBC_[0-9]+\.[0-9]+' \
    | sort -u | tr '\n' ' '
echo
echo "  -> Build host (Bookworm) needs GLIBC_2.36 max for our binary."
echo "     If the highest 'GLIBC_X.Y' listed above is < 2.36, switch to"
echo "     Dockerfile.bullseye (glibc 2.31 baseline)."

echo
echo "=== Shared libraries needed by nsfb =="
search_paths="/lib /lib/aarch64-linux-gnu /usr/lib /usr/lib/aarch64-linux-gnu /opt/lib /opt/share/lib"
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
    for dir in $search_paths; do
        if [ -e "$dir/$lib" ]; then
            found="$dir/$lib"
            break
        fi
    done
    if [ -n "$found" ]; then
        printf "  %-22s OK     %s\n" "$lib" "$found"
    else
        # also broader search in case the SONAME is different
        any=$(find /lib /usr/lib /opt 2>/dev/null -name "${lib%.so*}.so*" -print 2>/dev/null | first_n 3 | tr '\n' ' ')
        if [ -n "$any" ]; then
            printf "  %-22s SO MISMATCH (looked for %s, found: %s)\n" "$lib" "$lib" "$any"
        else
            printf "  %-22s MISSING (no variant found at all)\n" "$lib"
        fi
    fi
done

echo
echo "=== Framebuffer / display path =="
echo "  /dev/fb*  :"
ls -la /dev/fb* 2>/dev/null || echo "    (none — kernel uses DRM/KMS, no legacy fbdev)"
echo "  /dev/dri/ :"
ls -la /dev/dri 2>/dev/null
echo "  /sys/class/graphics:"
ls /sys/class/graphics 2>/dev/null
for f in /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/bits_per_pixel /sys/class/graphics/fb0/name; do
    [ -r "$f" ] && { printf "    %-50s : " "$f"; cat "$f"; }
done
echo "  /sys/class/drm:"
ls /sys/class/drm 2>/dev/null
for f in /sys/class/drm/card0-*/modes /sys/class/drm/card0/device/uevent; do
    [ -r "$f" ] && echo "  -- $f --" && cat "$f" 2>/dev/null | first_n 8
done

echo
echo "=== Input devices =="
ls /dev/input/event* 2>/dev/null
[ -r /proc/bus/input/devices ] && grep -E '^I:|^N:|^P:|^H:' /proc/bus/input/devices | first_n 24

echo
echo "=== Kernel modules / EPDC hint =="
lsmod 2>/dev/null | grep -iE 'epdc|eink|mxc|drm' | first_n 10
echo
echo "  dmesg (e-ink/drm):"
dmesg 2>/dev/null | grep -iE 'epdc|eink|mxc_epdc|drm|frame.?buffer' 2>/dev/null | first_n 10 \
    || echo "    (dmesg restricted to root or empty)"

echo
echo "=== Space / RAM =="
df -h /home/root 2>/dev/null | first_n 2
free 2>/dev/null | first_n 3

echo
echo "=== Done =="
