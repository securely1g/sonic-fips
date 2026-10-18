# Kerberos Debian packages

Build the four packages used by SONiC with the existing source-built runtime
payloads:

```sh
bazel build //krb5:libgssapi_krb5_2_deb //krb5:libk5crypto3_deb \
  //krb5:libkrb5_3_deb //krb5:libkrb5support0_deb
```

The package version is `1.21.3-5+fips`, as selected by Make. Native AMD64 and
ARM64 use the same package definitions with their respective compiled ELF files.

The original Debian control file keeps its exact-version relationships between
the Kerberos libraries. Debian's own helpers generate library symbols and
ldconfig triggers and expand the original GSS-API configure/purge scripts. The
shared metadata rule resolves dependencies from the actual library payloads,
including the SONiC-built OpenSSL library. The four existing debug TARs remain
paired with the same runtime files.

Generated control files and archives are build outputs; do not edit them
manually. Change the original metadata or the producer definitions instead.

Native CI installs the exact packages, checks their configured state and shared
library loading, then exercises reinstall, removal and purge. Final SONiC image
validation remains the image consumer's responsibility.
