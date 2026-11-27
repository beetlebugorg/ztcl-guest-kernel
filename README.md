# ztcl-guest-kernel

This repository holds the guest kernel config and patches that ztcl::vm uses.
The guest kernel is Linux, under GPL-2.0, and these patches are GPL-2.0 too.

ztcl and its other projects use only the built kernels, the config fragments, and the measured times from this repository.

## Contents

- `config/`: the config fragments, in the order that `build.sh` applies them.
- `patches/`: the kernel patches. Each patch has its measured gain in its header.
- `build.sh`: builds the kernel from the release archive, with the patches and the fragments, for a reproducible output.
- `TIMES.md`: the boot times on each hypervisor.

## Build

Run `./build.sh` on an x86-64 Linux host.
The output goes to `out/`: `bzImage`, `vmlinux`, `kernel.config`, and `SHA256SUMS`.
The build sets `SOURCE_DATE_EPOCH`, the build user, and the build host, so two builds give the same bytes.
