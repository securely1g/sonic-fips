#!/usr/bin/env python3
"""Apply the four reviewed production patches to upstream Distroless 0.9.4."""

import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import urllib.request


REGISTRY_COMMIT = "66827da16fb8ad74d76ee662de8cc0298c242abc"
PATCHES = {
    "0006-pkgconfig-files.patch": "sha256-niHKTSORtelvZTWYmKepjpfJmu6C7eJg2M05SywkWck=",
    "0002-include-fragments.patch": "sha256-iNpoe/p+zvHebAowncGruHEtEPSMrsIunHTfMNZOY5o=",
    "0004-pkgconfig-whitespace.patch": "sha256-BbwuLasmQqHdHM/hkR4szFussadKrhZR9mZg9qP6gu4=",
    "0005-multiarch-headers.patch": "sha256-WphbplQ5XKiQGJsKQB3Aq9c5b1DJdLe8iwkt0r93Xts=",
}


def main():
    source, evidence = map(Path, sys.argv[1:])
    evidence.mkdir(parents=True, exist_ok=True)
    receipts = []
    for name, integrity in sorted(PATCHES.items()):
        url = ("https://raw.githubusercontent.com/securely1g/sonic-bazel-registry/"
               + REGISTRY_COMMIT + "/modules/rules_distroless/0.9.4.sonic.4/patches/" + name)
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
        actual = "sha256-" + base64.b64encode(hashlib.sha256(data).digest()).decode()
        if actual != integrity:
            raise SystemExit(f"Patch checksum mismatch: {name}")
        subprocess.run(["patch", "--batch", "--fuzz=0", "-p1"], cwd=source, input=data, check=True)
        receipts.append({"url": url, "integrity": actual})
    (evidence / "distroless-inputs.json").write_text(json.dumps({"_generated": {"notice": "AUTO-GENERATED. DO NOT EDIT MANUALLY.", "generator": "krb5/prepare_distroless.py"}, "patches": receipts}, indent=2) + "\n")


if __name__ == "__main__":
    main()
