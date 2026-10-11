#!/usr/bin/env python3
"""Fetch checksum-pinned Debian packages used only as the upgrade-test baseline."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("manifest", type=Path)
parser.add_argument("directory", type=Path)
args = parser.parse_args()
architecture = subprocess.check_output(["dpkg", "--print-architecture"], text=True).strip()
args.directory.mkdir(parents=True, exist_ok=True)
selected = [row for row in json.loads(args.manifest.read_text()) if row["architecture"] == architecture]
if not selected:
    raise SystemExit("No pinned Debian upgrade baseline for " + architecture)
for row in selected:
    destination = args.directory / row["url"].rsplit("/", 1)[1]
    data = destination.read_bytes() if destination.exists() else urllib.request.urlopen(row["url"], timeout=60).read()
    if hashlib.sha256(data).hexdigest() != row["sha256"]:
        raise SystemExit("Upgrade baseline checksum mismatch: " + destination.name)
    destination.write_bytes(data)
(args.directory / "baseline.json").write_text(json.dumps(selected, indent=2) + "\n")
