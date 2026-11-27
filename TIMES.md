# Boot times

The times are in ms. Each guest has 1 CPU and 64 MB. The root is the signed image of ztcl: squashfs on dm-verity, with `dm-mod.create` on the command line and no initramfs. The agent of ztcl is the first process.

- "listen": the boot clock of the guest (`CLOCK_BOOTTIME`) when the agent listens on vsock.
- "answer": `ztcl::vm start` to the first 16 bytes of the agent over vsock, on the host.

The KVM host is an Intel Skylake at 4 GHz with 8 cores, with the builds of other work on it at the same time (load average 8 to 11). The load changes the numbers by a factor of 2. Each row pair ran round robin in one process, so both kernels saw the same load.

## KVM

| Kernel | listen, best | listen, p25 | answer, best | answer, p25 |
|---|---|---|---|---|
| ztcl CI kernel (6.12.10), vmlinux, load 8, 30 boots | 16.80 | 26.75 | 30.60 | 43.66 |
| this kernel, vmlinux, load 8, 30 boots | 6.14 | 12.00 | 16.32 | 27.66 |
| ztcl CI kernel, vmlinux, load 10, 40 boots | 19.42 | 32.67 | 34.70 | 51.51 |
| this kernel, vmlinux, load 10, 40 boots | 10.88 | 14.55 | 23.52 | 32.09 |
| ztcl CI kernel, bzImage, load 10, 40 boots | 19.79 | 28.64 | 39.33 | 53.75 |
| this kernel, bzImage, load 10, 40 boots | 8.27 | 10.92 | 23.15 | 32.00 |

With the initramfs of `test-kvm.tcl` (`rdinit=/sbin/agent quiet`), load 10: listen best 18.40 before and 8.87 after.

## The gain of each change

Each gain is from `initcall_debug` or from the times of the kernel log, on KVM. The 8 boots of a row give the mean or the best, as the row says.

| Change | Where | Before | After |
|---|---|---|---|
| `# CONFIG_LEGACY_PTYS is not set` | `pty_init` | 2.66 | 0.52 |
| `# CONFIG_SERIO is not set` (no i8042 probe) | `i8042_init` | 1.04 | 0 |
| patch 0001, console fill | probe of the console | 3.1 to 3.5 | 0.4 to 0.6 |
| patch 0002, fast strings | start of init, mean | 5.84, 5.96 | 5.40, 5.61 |
| patch 0003 and `ioapic_clean` | `enable_IO_APIC` | 0.96 | under 0.01 |
| patch 0004, no poison | mount of the root to init, mean | 1.02, 1.83 | 0.27, 0.24 |
| `percpu_alloc=page` | listen, best of 30 | 16.62 | 13.12 |
| `loglevel=1`, the effect of `console=ttynull` on the warnings of the boot | listen, p25 of 30 | 15.74 | 13.52 |
| `CONFIG_CRYPTO_SHA256_SSSE3` | dm-verity uses `sha256-avx2` | | |

The changes that gave no measured gain and are not in the kernel: a cap of the first fill of the vsock receive queue (64 buffers), `virtio_blk.queue_depth`, `io_delay=none`, `noreplace-smp`, and `no_timer_check` (KVM sets it already).

## The time that is left, on KVM

From one boot with `initcall_debug`, after these changes:

- The first write of the guest to each page of its memory is a fault in the host. The guest has 18.6 MB of resident memory after the boot. The init of the page structures (1.7 ms) and the per-CPU memory were the largest parts of this cost.
- Each access of the guest to a register of a virtio-mmio device of the monitor is an exit to user space. A virtio probe has about 40 to 50 of these accesses and takes 0.4 ms to 0.7 ms (console, vsock, and block).
- The patches of the alternatives: 0.7 ms.
- The sysfs nodes of the parameters of the built-in modules (`param_sysfs_builtin_init`): 0.5 ms.
- The mount of the root through dm-verity: 0.9 ms.

## Virtualization.framework and WHP

Not measured yet. The measurements go through the sessions of those hosts.
