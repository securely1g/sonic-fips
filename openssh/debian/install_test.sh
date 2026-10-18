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
version=1:10.0p1-7+fips
apt-get -y --no-install-recommends install openssh-client
before_version=$(dpkg-query -W -f='${Version}' openssh-client)
printf '%s\n' "$before_version" > "$out/before-install.txt"
dpkg --compare-versions "$before_version" lt "$version"
archives=("$out/openssh-client_${version#*:}_${architecture}.deb"
          "$out/libssl3t64_3.5.7-1~deb13u2+fips_${architecture}.deb")
apt-get -y --no-install-recommends install "${archives[@]}"
test "$(dpkg-query -W -f='${Version}' openssh-client)" = "$version"
test "$(dpkg-query -W -f='${Status}' openssh-client)" = 'install ok installed'
test -z "$(dpkg --audit)"
apt-get check
ssh -V
ssh-keygen -q -t ed25519 -N '' -f /tmp/package-check-key
ssh-keygen -l -f /tmp/package-check-key.pub
ssh-agent -s > "$out/ssh-agent.txt"
# The real postinst must create the group and adjust the binary permissions.
test "$(stat -c '%G:%a' /usr/bin/ssh-agent)" = '_ssh:2755'
test "$(stat -c '%a' /usr/lib/openssh/ssh-keysign)" = 4755
dpkg-query -W -f='${Conffiles}' openssh-client | grep -F /etc/ssh/ssh_config
test -f /usr/lib/tmpfiles.d/openssh-client.conf

printf '\n# Keep the administrator setting across reinstall.\n' >> /etc/ssh/ssh_config
before=$(sha256sum /etc/ssh/ssh_config)
apt-get -y --reinstall --no-install-recommends install "${archives[@]}"
test "$(sha256sum /etc/ssh/ssh_config)" = "$before"
test "$(stat -c '%G:%a' /usr/bin/ssh-agent)" = '_ssh:2755'
apt-get -y remove openssh-client
test ! -e /usr/bin/ssh
test -f /etc/ssh/ssh_config
apt-get -y purge openssh-client
test ! -e /etc/ssh/ssh_config
test ! -e /usr/lib/tmpfiles.d/openssh-client.conf
test -z "$(dpkg --audit)"
apt-get check
printf '{"initial_configuration":"passed","upgrade":"passed","reinstall":"passed","remove":"passed","purge":"passed"}\n' > "$out/installation.json"
