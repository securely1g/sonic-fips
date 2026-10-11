# OpenSSL source packages

This build uses the OpenSSL and Debian source versions selected by
[`rules/openssl.mk`](../rules/openssl.mk): **3.5.7-1~deb13u2**, with SONiC's
existing FIPS integration patches. It produces runtime and debug TARs for
container layers.

## Source and build contract

[`sources.bzl`](sources.bzl) downloads the upstream source archive and Debian
source patch archive with the SHA-256 values in Debian's published
`openssl_3.5.7-1~deb13u2.dsc`. It applies the same order as Make:

1. The two active SONiC runtime patches in `src/openssl.patch/series`.
2. All 23 patches in Debian's source series, including its security fixes.
3. The four SONiC test patches added to the Debian series by Make.

The two runtime patches have refreshed surrounding lines for OpenSSL 3.5.7.
Their resulting source is byte-for-byte identical to applying the original
patches through Make's GNU patch/quilt behavior. No cryptographic logic changes.

`rules_foreign_cc` runs the vendor's Configure and Make targets with declared
GCC, Make and Perl tools. Configure keeps Debian's architecture target and
feature switches, including FIPS, zlib and zstd support. `--prefix=/usr` and
`--openssldir=/usr/lib/ssl` describe the installed system; `DESTDIR` stages the
files privately in the Bazel action. Generated Perl scripts retain
`#!/usr/bin/perl` for the installed system. The build uses Make's fixed source
timestamp. Compiler prefix maps remove the private build-directory prefix from
debug information.

The source supports native AMD64 and ARM64 on Debian Trixie. ARM64 omits the
x86 PadLock engine, as Debian's build does.

## Public targets

| Target | Consumer |
| --- | --- |
| `//openssl:build` | C/C++ consumers needing generated headers, `libcrypto.so.3` and `libssl.so.3` |
| `//openssl:libssl3t64_pkg` | Runtime libraries and the architecture's engine plugins |
| `//openssl:libssl3t64_pkg.debug_symbols` | Matching DWARF symbols for those exact libraries |
| `//openssl:openssl_pkg` | The OpenSSL command, helper scripts and runtime configuration |
| `//openssl:openssl_pkg.debug_symbols` | Matching symbols for the command |

Runtime ELF files are stripped through the shared `sonic_deploy_tar` rule;
separate symbols use the same build IDs. Engine plugins are additional build
outputs, so linking a C/C++ consumer does not link every plugin into it.
These targets do not produce Debian packages or install documentation packages.

The SONiC mode-selection behavior and SymCrypt integration remain the original
project code. These build targets alone do not establish FIPS certification;
SymCrypt producer validation and final image integration are separate required
work.

## Validation

`//openssl:package_test` checks the installed command, library loading, runtime
paths, matching build IDs and debug-link checksums, and GDB source lookup.

The full OpenSSL suite also needs the SymCrypt engine and provider: SONiC's
existing test patch copies them before running its tests. Those components link
against OpenSSL, so the core build cannot depend on their test setup. A separate
integration test must supply their declared source-build outputs. This full-suite
integration remains pending while that producer is migrated; a core package
check does not establish that the full suite passed.
