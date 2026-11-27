# ztcl-guest-kernel

This repository holds the guest kernel config and patches that ztcl::vm uses.
The guest kernel is Linux 6.12.119, under GPL-2.0, and these patches are GPL-2.0 too.

ztcl and its other projects use only the built kernels, the config fragments, and the measured times from this repository.

## Contents

- `config/`: the config fragments, in the order that `build.sh` merges them onto `tinyconfig`. `10-base` and `20-x86_64` are the fragments of ztcl (`tools/vm-guest`). `30-boot` and `40-ARCH-boot` are the options for a fast boot.
- `patches/`: the kernel patches. The header of each patch gives its effect and its measured gain.
- `build.sh`: builds the kernel from the release archive of kernel.org, with the patches and the fragments.
- `build-inc.sh`: an incremental build in `work/` for tests.
- `TIMES.md`: the boot times, and the gain of each change.
- `.github/workflows/build.yml`: builds both architectures on each push to main. The artifacts are `guest-kernel-x86_64` and `guest-kernel-arm64`.

## Build

Run `./build.sh` on Linux. `ARCH=arm64` builds the arm64 `Image`, and `LLVM=1` builds it with clang and ld.lld on an x86-64 host.

The output goes to `out/ARCH/`: the kernel (`bzImage` and `vmlinux` on x86-64, `Image` on arm64), `System.map`, `kernel.config`, and `SHA256SUMS`.
The build sets `SOURCE_DATE_EPOCH`, the build user, and the build host, so two builds with the same compiler give the same bytes.

## The boot options

The x86-64 kernel has a built-in command line: `percpu_alloc=page console=ttynull tsc=reliable ioapic_clean`. The command line of the VMM comes after it, so a `console=` of the VMM still works.

`ioapic_clean` (patch 0003) tells the kernel that each I/O APIC is in its reset state. Use this kernel only with a VMM that makes a new I/O APIC for each boot, as the monitors of ztcl do.
