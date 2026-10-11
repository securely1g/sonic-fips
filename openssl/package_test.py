"""Exercise the installed OpenSSL programs and their matching debug symbols."""

import hashlib
import os
from pathlib import Path, PurePosixPath
import platform
import re
import struct
import subprocess
import sys
import tarfile
import tempfile
import zlib


def run(*args, **kwargs):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, **kwargs)


def unpack_files(archive, destination):
    """Read package files without creating the installed system's absolute links."""
    entries = {}
    with tarfile.open(archive) as source:
        for member in source:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts:
                raise AssertionError(f"Unsafe package entry: {member.name}")
            name = str(path)
            if any(entries.get(str(parent), None) and entries[str(parent)].issym()
                   for parent in path.parents):
                raise AssertionError(f"Package file is below a link: {name}")
            if name in entries and not member.isdir():
                raise AssertionError(f"Duplicate package file: {name}")
            entries[name] = member
            if member.isfile():
                target = destination / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.extractfile(member).read())
                target.chmod(member.mode)
            elif not (member.isdir() or member.issym()):
                raise AssertionError(f"Unexpected package entry type: {name}")
    return entries


def build_id(path):
    return re.search(r"Build ID: ([0-9a-f]+)", run("readelf", "-n", str(path))).group(1)


def check_symbols(binary, symbols, scratch):
    identifier = build_id(binary)
    debug = symbols / "usr/lib/debug/.build-id" / identifier[:2] / (identifier[2:] + ".debug")
    assert debug.is_file(), (binary, identifier)
    assert build_id(debug) == identifier
    assert ".debug_info" not in run("readelf", "-SW", str(binary))
    assert ".debug_info" in run("readelf", "-SW", str(debug))
    section = scratch / "debuglink"
    run("objcopy", "--dump-section", f".gnu_debuglink={section}", str(binary), str(scratch / "copy"))
    data = section.read_bytes()
    end = data.index(b"\0")
    assert data[:end].decode() == debug.name
    offset = (end + 1 + 3) & ~3
    assert struct.unpack_from("<I", data, offset)[0] == zlib.crc32(debug.read_bytes())
    dynamic = run("readelf", "-d", str(binary))
    assert not re.search(r"(?:RPATH|RUNPATH).*?(?:bazel-out|execroot|build_tmpdir)", dynamic), dynamic


def check_gdb(binary, symbols, function, source):
    output = run(
        "gdb", "--batch", "--nx", "--quiet",
        "-ex", "set debuginfod enabled off",
        "-ex", f"set debug-file-directory {symbols / 'usr/lib/debug'}",
        "-ex", f"file {binary}",
        "-ex", f"info line {function}",
    )
    assert re.search(r"Line [0-9]+ of .*" + re.escape(source), output), output


def main():
    assert len(sys.argv) == 5
    multiarch = {"x86_64": "x86_64-linux-gnu", "aarch64": "aarch64-linux-gnu"}[platform.machine()]
    with tempfile.TemporaryDirectory(dir=os.environ.get("TEST_TMPDIR")) as temporary:
        root = Path(temporary) / "root"
        symbols = Path(temporary) / "symbols"
        library_entries = unpack_files(sys.argv[1], root)
        command_entries = unpack_files(sys.argv[2], root)
        library_debug_entries = unpack_files(sys.argv[3], symbols)
        command_debug_entries = unpack_files(sys.argv[4], symbols)
        for entries in [library_entries, command_entries, library_debug_entries, command_debug_entries]:
            for name, member in entries.items():
                assert (member.uid, member.gid) == (0, 0), (name, member.uid, member.gid)
        library_dir = root / "usr/lib" / multiarch
        names = ["libcrypto.so.3", "libssl.so.3", "engines-3/afalg.so", "engines-3/loader_attic.so"]
        if platform.machine() == "x86_64":
            names.append("engines-3/padlock.so")
        expected = {"usr/lib/" + multiarch + "/" + name for name in names}
        actual = {name for name in library_entries if ".so" in name}
        assert actual == expected, (actual, expected)
        command = root / "usr/bin/openssl"
        for binary in [command] + [library_dir / name for name in names]:
            check_symbols(binary, symbols, Path(temporary))
        assert command_entries["etc/ssl/private"].mode == 0o700
        for name in ["certs", "private", "openssl.cnf"]:
            assert command_entries["usr/lib/ssl/" + name].linkname == "/etc/ssl/" + name
        for script in ["usr/bin/c_rehash", "usr/lib/ssl/misc/CA.pl", "usr/lib/ssl/misc/tsget.pl"]:
            assert (root / script).read_text().splitlines()[0] == "#!/usr/bin/perl"

        environment = dict(os.environ, LD_LIBRARY_PATH=str(library_dir), OPENSSL_CONF=str(root / "etc/ssl/openssl.cnf"))
        version = run(str(command), "version", "-a", env=environment)
        assert "OpenSSL 3.5.7" in version, version
        assert 'OPENSSLDIR: "/usr/lib/ssl"' in version, version
        assert 'ENGINESDIR: "/usr/lib/' + multiarch + '/engines-3"' in version, version
        digest = run(str(command), "dgst", "-sha256", input="abc", env=environment)
        assert hashlib.sha256(b"abc").hexdigest() in digest, digest
        # Load the installed libraries in a new process so LD_LIBRARY_PATH is
        # applied before the dynamic loader initializes its search path.
        run(sys.executable, "-c", "import ctypes,sys; [ctypes.CDLL(x) for x in sys.argv[1:]]",
            *[str(library_dir / name) for name in names], env=environment)
        check_gdb(command, symbols, "main", "apps/openssl.c")
        check_gdb(library_dir / "libcrypto.so.3", symbols, "OPENSSL_init_crypto", "crypto/init.c")
        print(f"Installed OpenSSL 3.5.7: {len(names) + 1} runtime/debug pairs, CLI digest, library loading and GDB passed")


if __name__ == "__main__":
    main()
