"""Create SymCrypt's scoped compiler using upstream's public repository macro."""

load("@toolchains_llvm//toolchain:rules.bzl", "llvm_toolchain")

def _clang_impl(_ctx):
    # Upstream's llvm module extension is root-only. Calling its public macro
    # here lets the source owner supply the same compiler to downstream images.
    llvm_toolchain(
        name = "symcrypt_llvm",
        llvm_version = "19.1.7",
        stdlib = {"": "dynamic-stdc++-14"},
        sysroot = {
            "linux-x86_64": str(Label("@symcrypt_sysroot_amd64//root:sysroot")),
            "linux-aarch64": str(Label("@symcrypt_sysroot_arm64//root:sysroot")),
        },
    )

clang = module_extension(implementation = _clang_impl)
