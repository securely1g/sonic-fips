# SymCrypt Debian package

`//symcrypt:symcrypt_openssl_deb` packages the existing sealed `//symcrypt:runtime`
output. The compiled libraries, provider, engine, integrity check and paired
debug files are unchanged.

The existing owner control file under `src/SymCrypt-OpenSSL-Debian/debian/control`
supplies the package name, version, description and OpenSSL dependency. A small
adapter makes that binary control usable by dpkg's source metadata tools. It
corrects `Architecture: all` to the actual native AMD64 or ARM64 architecture;
these files are compiled ELF libraries, not architecture-independent data.
The shared metadata rule derives additional library dependencies and symbols
from the actual payload.

Generated controls, symbols and DEBs are outputs; do not edit them manually.
This package is one input to the final image installation, not a prewritten dpkg
installed-state record.
