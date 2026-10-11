#!/bin/bash
# Run only in the disposable native Debian CI container after building packages.
set -euo pipefail
if [ ! -f /.dockerenv ] || [ "${SONIC_DEB_TEST_CONTAINER:-}" != 1 ]; then
    echo "Run this destructive package lifecycle check only in the disposable test container." >&2
    exit 1
fi
package_directory=$(realpath "$1")
version=3.5.7-1~deb13u2+fips
architecture=$(dpkg --print-architecture)
case "$architecture" in amd64) multiarch=x86_64-linux-gnu;; arm64) multiarch=aarch64-linux-gnu;; *) exit 1;; esac
export DEBIAN_FRONTEND=noninteractive
packages=("$package_directory/libssl3t64_${version}_${architecture}.deb"
          "$package_directory/openssl_${version}_${architecture}.deb"
          "$package_directory/libssl-dev_${version}_${architecture}.deb")

# Current Debian mirrors may be newer than this source checkout. Seed an
# explicitly pinned stock baseline first, then test the real +fips upgrade.
script_directory=$(cd "$(dirname "$0")" && pwd)
python3 "$script_directory/../../tools/bazel/fetch_deb_baseline.py" \
    "$script_directory/upgrade_baseline.json" "$package_directory/baseline"
apt-get -y --allow-downgrades --no-install-recommends install "$package_directory"/baseline/*.deb
for package in openssl libssl3t64; do
    test "$(dpkg-query -W -f='${Version}' "$package")" = 3.5.7-1~deb13u2
done
dpkg-query -W openssl libssl3t64 > "$package_directory/before-install.txt"
apt-get -y --no-install-recommends install "${packages[@]}"
for package in libssl3t64 openssl libssl-dev; do
    test "$(dpkg-query -W -f='${Version}' "$package")" = "$version"
    test "$(dpkg-query -W -f='${Status}' "$package")" = 'install ok installed'
done
test -z "$(dpkg --audit)"
apt-get check
openssl version -a
openssl rand -hex 32
openssl dgst -sha256 /etc/ssl/openssl.cnf
# Debian must record the configuration and library ownership itself.
dpkg-query -W -f='${Conffiles}' openssl | grep -F /etc/ssl/openssl.cnf
dpkg-query -S /usr/lib/"$multiarch"/libssl.so.3

printf '\n# Keep this local administrator change across reinstall.\n' >> /etc/ssl/openssl.cnf
before=$(sha256sum /etc/ssl/openssl.cnf)
apt-get -y --reinstall --no-install-recommends install "${packages[@]}"
test "$(sha256sum /etc/ssl/openssl.cnf)" = "$before"
test -z "$(dpkg --audit)"
apt-get check

# This image is disposable: removal may also remove ca-certificates, which
# depends on openssl. Check dpkg's normal remove versus purge conffile behavior.
apt-get -y remove openssl libssl-dev
test ! -e /usr/bin/openssl
test -f /etc/ssl/openssl.cnf
apt-get -y purge openssl libssl-dev
test ! -e /etc/ssl/openssl.cnf
test -z "$(dpkg --audit)"
apt-get check
printf '{"initial_configuration":"passed","upgrade":"passed","reinstall":"passed","remove":"passed","purge":"passed"}\n' > "$package_directory/installation.json"
