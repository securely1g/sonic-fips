#!/usr/bin/env python3
"""Record one SONiC registry endpoint and prepare Draft CI's Bazel command."""

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[2]
MAIN = "https://raw.githubusercontent.com/securely1g/sonic-bazel-registry/main"
DRAFT = "https://raw.githubusercontent.com/securely1g/sonic-bazel-registry/codex/debian-gcc-toolchains"


def record(artifacts):
    registry = os.environ.get("SONIC_BAZEL_REGISTRY_URL", MAIN)
    if registry not in (MAIN, DRAFT):
        raise ValueError("Expected main or the reviewed Debian GCC registration branch")
    configuration = (ROOT / ".bazelrc").read_text()
    endpoints = [line for line in configuration.splitlines()
                 if "--registry=" in line and "securely1g/sonic-bazel-registry/" in line]
    if endpoints != ["common --registry=" + MAIN]:
        raise ValueError("Expected exactly the canonical SONiC main registry endpoint")
    branch = registry.removeprefix(MAIN.removesuffix("main"))
    ref = "refs/heads/" + branch
    revision = subprocess.check_output(
        ["git", "ls-remote", "https://github.com/securely1g/sonic-bazel-registry.git", ref],
        text=True).split()
    if len(revision) != 2 or revision[1] != ref or not re.fullmatch(r"[0-9a-f]{40}", revision[0]):
        raise ValueError("Could not determine the selected registry branch revision")
    artifacts.mkdir(parents=True, exist_ok=True)
    (artifacts / "declared.bazelrc").write_text(configuration)
    effective = artifacts.resolve() / "effective.bazelrc"
    effective.write_text(configuration.replace(MAIN, registry))
    if registry != MAIN:
        binary = shutil.which("bazel")
        if not binary:
            raise ValueError("Install Bazel before selecting Draft inputs")
        commands = artifacts.resolve() / "draft-bin"
        commands.mkdir(exist_ok=True)
        wrapper = commands / "bazel"
        wrapper.write_text("#!/bin/sh\nexec " + shlex.quote(binary) +
                           " --noworkspace_rc --bazelrc=" + shlex.quote(str(effective)) +
                           ' "$@"\n')
        wrapper.chmod(0o755)
        if os.environ.get("GITHUB_PATH"):
            with open(os.environ["GITHUB_PATH"], "a") as path_file:
                path_file.write(str(commands) + "\n")
    (artifacts / "registry-inputs.json").write_text(json.dumps({
        "declared_registry": MAIN, "registry": registry,
        "observed_revision": revision[0], "draft_validation": registry != MAIN,
    }, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", type=Path)
    record(parser.parse_args().artifacts)
