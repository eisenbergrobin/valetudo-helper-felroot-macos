#!/usr/bin/env bash
# Build valetudo-helper-felroot as a fully static binary for x86_64-linux
# and aarch64-linux using zig cc.
#
# Requirements:
#   - zig (any recent 0.13+ will do) on PATH
#   - libusb source vendored under third_party/libusb/
#   - optional: upx on PATH for compression
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/src/main.c"
LIBUSB="$ROOT/third_party/libusb"
OUT="$ROOT/build"

# The release binaries are static Linux executables, so there is nothing to run on macOS.
# Build a native one there instead, against libusb from Homebrew. No zig needed.
if [ "$(uname -s)" = "Darwin" ]; then
    cflags=""
    libs=""
    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists libusb-1.0; then
        cflags="$(pkg-config --cflags libusb-1.0)"
        libs="$(pkg-config --libs libusb-1.0)"
    else
        for p in "${LIBUSB_PREFIX:-}" /opt/homebrew /usr/local; do
            if [ -f "$p/include/libusb-1.0/libusb.h" ]; then
                cflags="-I$p/include/libusb-1.0"
                libs="-L$p/lib -lusb-1.0"
                break
            fi
        done
    fi
    [ -n "$libs" ] || { echo "libusb not found - install it with: brew install libusb pkg-config"; exit 1; }

    mkdir -p "$OUT"
    echo "==> building for macOS/$(uname -m) -> $OUT/valetudo-helper-felroot-macos"
    # cflags/libs are unquoted on purpose: they are whitespace separated flag lists
    "${CC:-cc}" -O2 -Wall -o "$OUT/valetudo-helper-felroot-macos" "$SRC" \
        $cflags $libs -framework IOKit -framework CoreFoundation
    if command -v codesign >/dev/null 2>&1; then codesign --force --sign - "$OUT/valetudo-helper-felroot-macos"; fi
    exit 0
fi

command -v zig >/dev/null || { echo "zig not found on PATH"; exit 1; }

LIBUSB_SRCS=(
    "$LIBUSB/core.c"
    "$LIBUSB/descriptor.c"
    "$LIBUSB/io.c"
    "$LIBUSB/strerror.c"
    "$LIBUSB/sync.c"
    "$LIBUSB/hotplug.c"
    "$LIBUSB/os/linux_usbfs.c"
    "$LIBUSB/os/linux_netlink.c"
    "$LIBUSB/os/events_posix.c"
    "$LIBUSB/os/threads_posix.c"
)

mkdir -p "$OUT"

build_target() {
    local target="$1"
    local outname="$2"
    local work="$OUT/$target"
    echo "==> building for $target -> $outname"

    rm -rf "$work"
    mkdir -p "$work"

    cat > "$work/config.h" <<'EOF'
#ifndef CONFIG_H
#define CONFIG_H
#define PACKAGE_VERSION "1.0.27"
#define DEFAULT_VISIBILITY __attribute__((visibility("default")))
#define HAVE_CLOCK_GETTIME 1
#define HAVE_DECL_TIMERFD_CREATE 0
#define HAVE_GETTIMEOFDAY 1
#define HAVE_LIBUSB_DESCRIPTORS_H 1
#define HAVE_NFDS_T 1
#define HAVE_POLL 1
#define HAVE_PTHREAD 1
#define HAVE_PTHREAD_CANCEL 1
#define HAVE_STDINT_H 1
#define HAVE_STRDUP 1
#define HAVE_SYS_TIME_H 1
#define OS_LINUX 1
#define PLATFORM_POSIX 1
#define THREADS_POSIX 1
#define POLL_NFDS_T nfds_t
#define PRINTF_FORMAT(a, b) __attribute__((format(__printf__, a, b)))
#define HAVE_PIPE2 1
#define HAVE_VASNPRINTF 0
#define HAVE_STRLCPY 0
#define HAVE_STRLCAT 0
#define HAVE_DECL_ENODATA 1
#endif
EOF

    local cflags=(
        -target "$target"
        -static
        -Os
        -ffunction-sections
        -fdata-sections
        -fvisibility=hidden
        -I"$LIBUSB"
        -I"$LIBUSB/os"
        -I"$work"
        -DHAVE_CONFIG_H
        -DENABLE_LOGGING=1
        -DUSE_SYSTEM_LOGGING_FACILITY=0
        -D_GNU_SOURCE
    )

    local objlist=()
    local i=0
    for src in "${LIBUSB_SRCS[@]}"; do
        local obj="$work/libusb_$i.o"
        zig cc "${cflags[@]}" -c "$src" -o "$obj"
        objlist+=("$obj")
        i=$((i+1))
    done

    zig cc "${cflags[@]}" -c "$SRC" -o "$work/main.o"

    zig cc -target "$target" -static -Os \
        -Wl,--gc-sections -Wl,-s \
        "${objlist[@]}" "$work/main.o" \
        -o "$OUT/$outname" -lpthread

    ls -lh "$OUT/$outname"
}

build_target x86_64-linux-musl   valetudo-helper-felroot-amd64
build_target aarch64-linux-musl valetudo-helper-felroot-arm64

echo
echo "Done. Artifacts:"
ls -lh "$OUT"/valetudo-helper-felroot-*
