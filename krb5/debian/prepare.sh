#!/bin/bash
# Generate the original Debian scripts and ABI policy from the built libraries.
set -euo pipefail
execroot=$PWD
absolute() { case "$1" in /*) printf '%s\n' "$1";; *) printf '%s/%s\n' "$execroot" "$1";; esac; }
bsdtar=$(absolute "$1")
makeshlibs=$(absolute "$2")
installdeb=$(absolute "$3")
control=$(absolute "$4")
changelog=$(absolute "$5")
out=$(absolute "$6")
shift 6
payloads=()
for path in "$@"; do payloads+=("$(absolute "$path")"); done
source_debian=$(dirname "$control")
packages=(libgssapi-krb5-2 libk5crypto3 libkrb5-3 libkrb5support0)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
mkdir debian
cp "$control" debian/control
cp "$changelog" debian/changelog
cp "$source_debian/libgssapi-krb5-2.postinst" "$source_debian/libgssapi-krb5-2.postrm" debian/
selection=()
for index in "${!packages[@]}"; do
    package=${packages[$index]}
    selection+=("-p$package")
    mkdir -p "debian/$package/DEBIAN"
    "$bsdtar" -xf "${payloads[$index]}" -C "debian/$package"
    cp "$source_debian/$package.symbols" "debian/$package.symbols"
done
export DH_COMPAT=13
export DEB_RULES_REQUIRES_ROOT=no
export DEB_BUILD_OPTIONS=noddebs
"$makeshlibs" "${selection[@]}" -Xkrb5/plugins -- -c4
"$installdeb" "${selection[@]}"
for package in "${packages[@]}"; do
    for member in symbols shlibs triggers; do
        cp "debian/$package/DEBIAN/$member" "$out/$package.$member"
    done
    touch "debian/$package.substvars"
    cp "debian/$package.substvars" "$out/$package.substvars"
done
for member in postinst postrm; do
    cp "debian/libgssapi-krb5-2/DEBIAN/$member" "$out/libgssapi-krb5-2.$member"
done
