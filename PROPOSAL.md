# Guest kernel features for the use cases of ztcl::vm

Each feature below is in the guest kernel only. Users never install a module on a host. Each feature is ranked by its gain against its size and its cost across kernel updates. The two top features are standard virtio devices. Their drivers are upstream Linux, so they need config lines only and no patch. The host side of each is in the virtio specification (OASIS virtio 1.2/1.3), so a ztcl agent can build it from the specification.

## 1. Free page reporting (virtio-balloon), for the VM pool

The effect: a paused guest of the pool gives its free pages back to the host. After a boot on KVM (7.3.6, 64 MB), the guest uses 8.4 MB (MemTotal 57,272 kB, MemFree 48,868 kB), but the host has 18.6 MB resident for it. About 10 MB is pages that the boot touched and freed again. With free page reporting the host can drop most of them, so a pooled guest needs about 9 to 10 MB in place of 18.6 MB. The resume does not change: a reported page that the guest uses again is a new zero page of the host.

Kernel: `CONFIG_VIRTIO_BALLOON=y` (it selects `PAGE_REPORTING`). No patch. The driver reports free blocks of at least 2 MiB (order 9 on x86-64, `page_reporting.page_reporting_order` sets it) a few seconds after they are free.

Host side (the virtio specification, "Traditional Memory Balloon Device"): device ID 5, feature `VIRTIO_BALLOON_F_REPORTING` (bit 5). The device has the queues inflateq, deflateq, and reporting_vq (with the feature, the reporting queue is the queue after the other queues of the negotiated features). The guest puts a list of buffers on reporting_vq. Each buffer is a range of guest physical memory that is free. The host releases each range (for example `madvise(MADV_DONTNEED)` on Linux, `madvise(MADV_FREE_REUSABLE)` on macOS, `DiscardVirtualMemory` or an unmap of the range on Windows), then gives the buffer back as used. The host can leave the balloon size at 0, and it need not implement inflate or deflate.

Size and cost: the driver is about 30 KB of code. Upstream keeps it, so a kernel update has no port. Measured on KVM (7.3.6) together with item 2: the initcalls of both take about 50 us with no device, and both add 90 KB to the loaded kernel (6,822,928 against 6,732,448 bytes). The boot times of 30 boots each are the same within the spread. Both are in the kernel since 2026-11-27. The resident memory of a pooled guest needs a host with the device.

## 2. virtio-fs DAX window, for shares

The effect: the guest maps the pages of a host file into its address space, with no copy into the page cache of the guest and no request for each read. A read of a file that the guest already mapped costs no exit. This helps reads of the same files again and again, as in container images, builds, and the tools of a dockyard sandbox.

Kernel: `CONFIG_FUSE_DAX=y`, with `FS_DAX`, `ZONE_DEVICE`, `MEMORY_HOTPLUG`, and `MEMORY_HOTREMOVE`. No patch. The mount option is `dax=always` (or `dax=inode`).

Host side (the virtio specification, "File System Device", the DAX window): the device has a shared memory region with shmid 0, the DAX window. On virtio-mmio the region is given by the registers SHMSel (0x0ac), SHMLenLow/High (0x0b0, 0x0b4), and SHMBaseLow/High (0x0b8, 0x0bc); on virtio PCI by a `VIRTIO_PCI_CAP_SHARED_MEMORY_CFG` capability. The guest sends `FUSE_SETUPMAPPING` (foffset, len, flags read/write, moffset) and `FUSE_REMOVEMAPPING` requests, and the host maps the range of the open file at the offset `moffset` of the window. KVM and WHP can map a host file into the guest memory. Virtualization.framework has no DAX in `VZVirtioFileSystemDevice`, so this is for KVM and WHP only.

Size and cost: see item 1 (both together: 90 KB, about 50 us). Upstream keeps it.

## 3. The start of the agent

The effect: after the kernel starts `/sbin/agent`, the boot pays for the exec of the agent from the verity root and for the mounts of the agent. On KVM, the time from the main function of the agent to its listen is 1.2 ms to 1.5 ms. Most of it is the mounts. The agent tries virtio-fs, then 9p, for `share0` when the guest has no share. Each failed mount prints an error. Two changes cut this time, and neither needs a kernel module:

- The agent skips the share when the host gives none, for example from a flag on the command line. This is a change in ztcl.
- An agent in an initramfs inside the kernel image (`CONFIG_INITRAMFS_SOURCE`): the hash of the kernel in the manifest then covers the agent too, and the exec reads no block through dm-verity. The agent mounts the verity root for the programs of `exec`. The upper limit of the gain is the difference between the two boots of `test-kvm.sh`: 4.33 ms with the initramfs against 5.03 ms with the verity root.

An in-kernel launcher that starts the agent with no exec saves less than the exec itself (a static binary of about 100 KB), and it has a cost at each kernel update. It is not worth its cost.

## 4. Shared-memory rings for terminal and exec I/O

The effect: the bytes of a terminal or of `ztcl::vm exec` go through a ring in shared memory, with no virtqueue work for each packet. vsock costs one virtqueue buffer for each packet, and the host wakes for each one. For a terminal, the packets are small and few, so the gain is latency (microseconds), which a person does not see. For bulk output, vhost-vsock on KVM already moves more than 1 GB/s.

Cost: a new device, with a host side on three hypervisors, and a guest driver that we keep across each kernel update. The gain is small for the use cases. Do it only if a measured terminal or exec workload shows vsock as the limit.

## 5. Costs of each boot that a module could skip

From the boot logs, nothing large is left that a module can skip. The rest is in the hosts (the first write to each page of the guest, the exits for the registers of the devices), in the PCI enumeration on VZ (0.86 ms), and in the mount through dm-verity (0.4 ms to 0.8 ms). These are config or host work, not module work.
