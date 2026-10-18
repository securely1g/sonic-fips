#!/bin/bash
# Use only in a disposable native Debian CI container.
set -euo pipefail
if [ ! -f /.dockerenv ] || [ "${SONIC_DEB_TEST_CONTAINER:-}" != 1 ]; then
    echo "Run this destructive package lifecycle check only in the disposable test container." >&2
    exit 1
fi
out=$(realpath "$1")
export DEBIAN_FRONTEND=noninteractive
# Seed the pinned OpenSSL baseline before installing its source-built replacement.
script_directory=$(cd "$(dirname "$0")" && pwd)
python3 "$script_directory/../../tools/bazel/fetch_deb_baseline.py" \
    "$script_directory/../../openssl/debian/upgrade_baseline.json" "$out/baseline"
apt-get -y --allow-downgrades --no-install-recommends install "$out"/baseline/*.deb
architecture=$(dpkg --print-architecture)
case "$architecture" in amd64) multiarch=x86_64-linux-gnu;; arm64) multiarch=aarch64-linux-gnu;; *) exit 1;; esac
archives=("$out/symcrypt-openssl_1.11.0_${architecture}.deb"
          "$out/libssl3t64_3.5.7-1~deb13u2+fips_${architecture}.deb"
          "$out/openssl_3.5.7-1~deb13u2+fips_${architecture}.deb")
apt-get -y --no-install-recommends install "${archives[@]}"
test "$(dpkg-query -W -f='${Version}' symcrypt-openssl)" = 1.11.0
test "$(dpkg-query -W -f='${Architecture}' symcrypt-openssl)" = "$architecture"
test "$(dpkg-query -W -f='${Status}' symcrypt-openssl)" = 'install ok installed'
test -z "$(dpkg --audit)"
apt-get check
openssl list -providers -provider symcryptprovider
openssl rand -hex 32
apt-get -y --reinstall --no-install-recommends install "${archives[@]}"
openssl list -providers -provider symcryptprovider
apt-get -y remove symcrypt-openssl
test ! -e "/usr/lib/$multiarch/ossl-modules/symcryptprovider.so"
# With no conffiles, removal drops this local-only package from dpkg entirely.
# Reinstall it to exercise purge as a separate supported lifecycle operation.
apt-get -y --no-install-recommends install "${archives[@]}"
apt-get -y purge symcrypt-openssl
test -z "$(dpkg --audit)"
apt-get check
printf '{"initial_configuration":"passed","reinstall":"passed","remove":"passed","purge":"passed"}\n' > "$out/installation.json"
