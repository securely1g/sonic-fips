#!/bin/bash
# Generate installation metadata from the original Debian source and payloads.
set -euo pipefail
execroot=$PWD
absolute() { case "$1" in /*) printf '%s\n' "$1";; *) printf '%s/%s\n' "$execroot" "$1";; esac; }
bsdtar=$(absolute "$1")
makeshlibs=$(absolute "$2")
perl=$(absolute "$3")
installdeb=$(absolute "$4")
control=$(absolute "$5")
changelog=$(absolute "$6")
symbols=$(absolute "$7")
postinst=$(absolute "$8")
ssl=$(absolute "$9")
openssl=$(absolute "${10}")
dev=$(absolute "${11}")
out=$(absolute "${12}")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
mkdir -p debian/libssl3t64/DEBIAN debian/openssl/DEBIAN debian/libssl-dev/DEBIAN
cp "$control" debian/control
cp "$changelog" debian/changelog
cp "$symbols" debian/libssl3t64.symbols
cp "$postinst" debian/openssl.postinst
"$bsdtar" -xf "$ssl" -C debian/libssl3t64
"$bsdtar" -xf "$openssl" -C debian/openssl
"$bsdtar" -xf "$dev" -C debian/libssl-dev
export DH_COMPAT=13
export DEB_RULES_REQUIRES_ROOT=no
export DEB_BUILD_OPTIONS=noddebs
# This target builds the runtime library; installer udebs are separate outputs
# in Debian's rules and are not included in this runtime package contract.
"$makeshlibs" -plibssl3t64 -V -Xengines -Xossl-modules -- -c4
"$perl" -d -popenssl
"$installdeb" -plibssl3t64 -popenssl -plibssl-dev
for member in symbols shlibs triggers; do
    cp "debian/libssl3t64/DEBIAN/$member" "$out/libssl3t64.$member"
done
for member in postinst conffiles; do
    cp "debian/openssl/DEBIAN/$member" "$out/openssl.$member"
done
for package in libssl3t64 openssl libssl-dev; do
    touch "debian/$package.substvars"
    cp "debian/$package.substvars" "$out/$package.substvars"
done
