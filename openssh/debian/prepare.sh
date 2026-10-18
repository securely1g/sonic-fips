#!/bin/bash
# Expand the actual Debian client scripts, including user units and conffiles.
set -euo pipefail
execroot=$PWD
absolute() { case "$1" in /*) printf '%s\n' "$1";; *) printf '%s/%s\n' "$execroot" "$1";; esac; }
bsdtar=$(absolute "$1")
installdeb=$(absolute "$2")
systemduser=$(absolute "$3")
tmpfiles=$(absolute "$4")
control=$(absolute "$5")
changelog=$(absolute "$6")
data=$(absolute "$7")
out=$(absolute "$8")
source_debian=$(dirname "$control")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
mkdir -p debian/openssh-client/DEBIAN
cp "$control" debian/control
cp "$changelog" debian/changelog
for member in postinst postrm maintscript tmpfiles; do
    cp "$source_debian/openssh-client.$member" "debian/openssh-client.$member"
done
"$bsdtar" -xf "$data" -C debian/openssh-client
export DH_COMPAT=13
export DEB_RULES_REQUIRES_ROOT=no
"$tmpfiles" -popenssh-client
"$systemduser" -popenssh-client
"$installdeb" -popenssh-client
for member in preinst postinst prerm postrm conffiles; do
    cp "debian/openssh-client/DEBIAN/$member" "$out/openssh-client.$member"
done
cp debian/openssh-client.substvars "$out/openssh-client.substvars"
