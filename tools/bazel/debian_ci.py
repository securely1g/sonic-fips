#!/usr/bin/env python3
"""Build the component's actual Debian packages and retain their exact bytes."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess


COMPONENTS = {
    "openssl": ["libssl3t64_deb", "openssl_deb", "libssl_dev_deb"],
    "krb5": ["libgssapi_krb5_2_deb", "libk5crypto3_deb", "libkrb5_3_deb", "libkrb5support0_deb"],
    "symcrypt": ["symcrypt_openssl_deb"],
    "openssh": ["openssh_client_deb"],
}


def run(command, log, separate_stderr=False):
    with log.open("w") as stream:
        if separate_stderr:
            with log.with_suffix(".stderr.log").open("w") as errors:
                subprocess.run(command, stdout=stream, stderr=errors, check=True)
        else:
            subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--component", choices=COMPONENTS, required=True)
    parser.add_argument("--architecture", choices=["amd64", "arm64"], required=True)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--bazel-arg", action="append", default=[])
    args = parser.parse_args()
    cpu = {"amd64": "x86_64", "arm64": "aarch64"}[args.architecture]
    if platform.machine() != cpu:
        raise SystemExit(f"Native {cpu} required, found {platform.machine()}")
    out = args.artifacts.resolve()
    out.mkdir(parents=True, exist_ok=True)
    flags = [f"--platforms=@sonic_build_infra//platforms:{cpu}_trixie",
             f"--host_platform=@sonic_build_infra//platforms:{cpu}_trixie",
             "--jobs=4", *args.bazel_arg]
    targets = [f"//{args.component}:{name}" for name in COMPONENTS[args.component]]
    # DEB generation was explicitly approved for PR #33's source packages.
    run(["bazel", "aquery", "deps(set(" + " ".join(targets) + "))", *flags,
         "--include_file_write_contents", "--output=jsonproto"], out / "actions.json", separate_stderr=True)
    run(["bazel", "build", *flags, *targets,
         "//" + args.component + "/debian:package_validation",
         "--build_event_json_file=" + str(out / "events.json")], out / "build.log")
    artifacts = []
    for target in targets:
        files = subprocess.check_output(["bazel", "cquery", target, *flags, "--output=files"], text=True).splitlines()
        if len(files) != 1 or not files[0].endswith(".deb"):
            raise SystemExit(f"Expected one Debian package from {target}: {files}")
        source = Path(files[0])
        destination = out / source.name
        shutil.copyfile(source, destination)
        fields = subprocess.check_output(["dpkg-deb", "-f", str(destination)], text=True)
        (out / (source.name + ".control")).write_text(fields)
        architecture = subprocess.check_output(["dpkg-deb", "-f", str(destination), "Architecture"], text=True).strip()
        if architecture != args.architecture:
            raise SystemExit(f"Wrong package architecture: {architecture}")
        run(["dpkg-deb", "-c", str(destination)], out / (source.name + ".contents"))
        artifacts.append({"target": target, "filename": source.name,
                          "sha256": hashlib.sha256(destination.read_bytes()).hexdigest()})
    validation = subprocess.check_output(["bazel", "cquery", "//" + args.component + "/debian:package_validation", *flags, "--output=files"], text=True).splitlines()
    if not validation:
        raise SystemExit("Missing package validation receipts")
    for filename in validation:
        shutil.copyfile(filename, out / Path(filename).name)
    shutil.copyfile("MODULE.bazel.lock", out / "MODULE.bazel.lock")
    run(["bazel", "mod", "graph", *args.bazel_arg], out / "module-graph.txt")
    (out / "packages.json").write_text(json.dumps({
        "commit": subprocess.check_output(["git", "-c", f"safe.directory={Path.cwd()}", "rev-parse", "HEAD"], text=True).strip(),
        "pull_request_head": os.environ.get("CI_HEAD_SHA"),
        "machine": platform.machine(), "architecture": args.architecture,
        "component": args.component, "artifacts": artifacts,
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()
