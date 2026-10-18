# OpenSSH client Debian package

`//openssh:openssh_client_deb` packages the existing source-built client programs
and their configuration as `openssh-client` version `1:10.0p1-7+fips` for native
AMD64 or ARM64. The existing runtime and debug targets stay available.

The package uses the original source control, changelog and maintainer scripts.
Declared Debian helpers expand its configuration-file migration, user systemd
units and temporary-file policy. For example, initial configuration creates the
`_ssh` group and gives `ssh-agent` its expected group and setgid permissions.
Removing or purging the package follows the original Debian scripts. Library
dependencies are generated from the actual client ELF files.

Generated controls and archives are outputs; do not edit them manually. Update
the owner metadata or package definitions instead.
