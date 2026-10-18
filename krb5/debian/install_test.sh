#!/bin/bash
# Validate the actual packages in the disposable native Debian CI container.
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
version=1.21.3-5+fips
packages=(libgssapi-krb5-2 libk5crypto3 libkrb5-3 libkrb5support0)
archives=()
for package in "${packages[@]}"; do archives+=("$out/${package}_${version}_${architecture}.deb"); done
# Use the same source-built OpenSSL library, including its exact dependency data.
archives+=("$out/libssl3t64_3.5.7-1~deb13u2+fips_${architecture}.deb")
dpkg-query -W "${packages[@]}" > "$out/before-install.txt"
for package in "${packages[@]}"; do
    dpkg --compare-versions "$(dpkg-query -W -f='${Version}' "$package")" lt "$version"
done
apt-get -y --no-install-recommends install "${archives[@]}"
for package in "${packages[@]}"; do
    test "$(dpkg-query -W -f='${Version}' "$package")" = "$version"
    test "$(dpkg-query -W -f='${Status}' "$package")" = 'install ok installed'
done
test -z "$(dpkg --audit)"
apt-get check
python3 - <<'PY'
import ctypes
for library in ('libkrb5.so.3', 'libgssapi_krb5.so.2', 'libk5crypto.so.3', 'libkrb5support.so.0'):
    ctypes.CDLL(library)
PY
apt-get -y --reinstall --no-install-recommends install "${archives[@]}"
test -z "$(dpkg --audit)"
apt-get check
apt-get -y remove libgssapi-krb5-2
test "$(dpkg-query -W -f='${db:Status-Status}' libgssapi-krb5-2)" = config-files
apt-get -y purge libgssapi-krb5-2
test ! -e /etc/gss/mech.d/README
test -z "$(dpkg --audit)"
apt-get check
printf '{"initial_configuration":"passed","upgrade":"passed","reinstall":"passed","remove":"passed","purge":"passed"}\n' > "$out/installation.json"
