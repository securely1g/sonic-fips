#!/bin/sh
# Regenerate Debian's configure changes with declared build tools.
set -eu
"$AUTOCONF"
"$AUTOHEADER"
mkdir -p .pkgconfig-empty
export PKG_CONFIG_LIBDIR="$PWD/.pkgconfig-empty"
export PKG_CONFIG_PATH=
# Debian's extra version identifies the same source/patch set as the Make build.
./configure "$@" '--with-cflags=-DSSH_EXTRAVERSION=\"Debian-7+fips\"'
# Match Debian's configure post-processing: no consumer reads btmp anymore.
sed -i 's/^#define USE_BTMP .*/\/\* #undef USE_BTMP \*\//' config.h
