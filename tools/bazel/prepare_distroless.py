#!/usr/bin/env python3
"""Apply the three reviewed production patches to upstream Distroless 0.9.4."""

import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import urllib.request


REGISTRY_COMMIT = "2a5e1717b7d417e60ca3b471ee62510835c3f5cc"
PATCHES = {
    "0002-include-fragments.patch": "sha256-iNpoe/p+zvHebAowncGruHEtEPSMrsIunHTfMNZOY5o=",
    "0004-pkgconfig-whitespace.patch": "sha256-BbwuLasmQqHdHM/hkR4szFussadKrhZR9mZg9qP6gu4=",
    "0005-multiarch-headers.patch": "sha256-WphbplQ5XKiQGJsKQB3Aq9c5b1DJdLe8iwkt0r93Xts=",
}


def main():
    source, evidence = map(Path, sys.argv[1:])
    evidence.mkdir(parents=True, exist_ok=True)
    receipts = []
    for name, integrity in PATCHES.items():
        url = ("https://raw.githubusercontent.com/securely1g/sonic-bazel-registry/"
               + REGISTRY_COMMIT + "/modules/rules_distroless/0.9.4.sonic.3/patches/" + name)
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
        actual = "sha256-" + base64.b64encode(hashlib.sha256(data).digest()).decode()
        if actual != integrity:
            raise SystemExit(f"Patch checksum mismatch: {name}")
        subprocess.run(["patch", "--batch", "--fuzz=0", "-p1"], cwd=source, input=data, check=True)
        receipts.append({"url": url, "integrity": actual})
    (evidence / "distroless-inputs.json").write_text(json.dumps(receipts, indent=2) + "\n")


if __name__ == "__main__":
    main()
