# Temporary FIPS source integration

This branch composes unlanded source features for downstream native validation.
It is not a replacement for reviewing and merging the individual source PRs.

| Source feature | Exact commit |
| --- | --- |
| [OpenSSL #1](https://github.com/securely1g/sonic-fips/pull/1) | `3d80284735c155e49efa818640837a0b59b057b1` |
| [OpenSSH #2](https://github.com/securely1g/sonic-fips/pull/2) | `499b4d68adb325cea2fbe1b6a31b20defa6c3b72` |
| [Kerberos #3](https://github.com/securely1g/sonic-fips/pull/3) | `79f8d2242f7159bfd9590e8a971c5a6e1007e4e8` |
| [SymCrypt #4](https://github.com/securely1g/sonic-fips/pull/4) | `1e4584bc8a7faec873796090667a8132535747f0` |
| [OpenSSL vendor suite #5](https://github.com/securely1g/sonic-fips/pull/5) | `2c5c77d3f00f5429e5ebf57f013b5e0a7c999028` |

The merged MODULE keeps every component's source and APT declarations, selects
Distroless `0.9.4.sonic.4`, and selects shared infra
`0.0.17-1f3e526a29e5fc391b42b11925a41889a44aa7a0`. All draft workflows use that same
infra source override. Ordinary registry endpoints remain SONiC main and BCR.

Component production sources and package APIs remain with their owning PRs.
The complete OpenSSL provider-dependent suite is available at
`//openssl/integration:openssl_symcrypt_test` through its separate source test feature.
It stages the source-built plugins privately and preserves the original test selection.
