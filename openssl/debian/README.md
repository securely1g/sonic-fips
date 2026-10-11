# Install the source-built OpenSSL packages

The existing runtime and debug TAR targets remain the source of the packaged
files. These targets add real Debian packages so the image installer can run
OpenSSL's original configuration script and let dpkg record installed files,
configuration files and library triggers:

```sh
bazel build //openssl:libssl3t64_deb //openssl:openssl_deb //openssl:libssl_dev_deb
```

The Debian version is `3.5.7-1~deb13u2+fips`, matching `rules/openssl.mk` and
Make's `+fips` suffix. The target platform selects `amd64` or `arm64`.

The package metadata comes from the same pinned Debian source archive used to
compile OpenSSL. `dh_makeshlibs`, `dh_perl` and `dh_installdeb` generate the
library metadata, Perl dependencies, conffile list, ldconfig trigger and final
maintainer script. The shared `debian_metadata` rule then inspects the actual
ELF files to resolve `${shlibs:Depends}` and runs `dpkg-gencontrol`.
`libssl-dev` retains the exact-version dependency on `libssl3t64`.

For example, installing the OpenSSL package records `/etc/ssl/openssl.cnf` as a
configuration file. Reinstalling the package preserves an administrator's edit;
removing the package keeps that file; purging it deletes the file. This is dpkg's
normal behavior rather than a prewritten installed-package record.

`//openssl:libssl3t64_symbols` publishes the generated library ABI metadata for
other source packages. It describes which Debian library version supplies each
exported symbol; consumers use it with their own ELF files to derive dependencies.

Upstream `pkg_tar` adds the explicit parent-directory entries that dpkg needs,
while preserving the runtime payload bytes and executable modes.

All generated control files, symbols, substvars and package archives are outputs.
Do not edit them manually. Update the owner inputs or build definitions instead.

## Validation

The native AMD64 and ARM64 workflow retains the exact DEBs, their checksums,
control fields and file lists. It tests upgrading Debian's OpenSSL to the SONiC
packages from a checksum-pinned stock Debian baseline, initial configuration,
cryptographic commands, reinstall with a changed
configuration, removal and purge in its disposable Debian container. This is
package-level validation; the final SONiC image has its own integration checks.
