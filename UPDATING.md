# Kernel updates

The guest kernel follows the newest stable release of Linux, from kernel.org. It does not follow mainline or the release candidates.

## Point releases

A point release (for example 7.3.6 to 7.3.7) has fixes, often for security. The workflow Update (`.github/workflows/update.yml`) checks kernel.org each day at 06:17 UTC. For a new stable version it:

1. Builds the kernel with `build.sh`, our fragments, and all the patches, for x86-64 and arm64.
2. Runs the boot test of ztcl (`tools/vm-guest/test-kvm.sh`) on KVM with the bzImage and with the vmlinux.
3. Times 20 boots of the new kernel and 20 of the current one, round robin, with the signed verity root (`tools/bench.sh`).
4. Opens a PR named `update-linux-VERSION` with the results of the test, the times, and the commits of the changelog that touch the parts that the guest uses.

Merge the PR of a point release within a few days, when the test passes and the times are no worse than the spread of the runner. A runner is a VM, so its times are slower than on a host. For a large change of the times, measure again on a host before the merge.

## A new stable series

A new series (for example 7.3 to 7.4) comes through the same workflow when kernel.org marks it as the newest stable. kernel.org has no ChangeLog file for the first release of a series, so the PR links to the release notes. Before the merge, also check the config: compare `kernel.config` of the new build with the current one, and look for options that a new tinyconfig turns on, or options that are gone. Then ask for the times on Virtualization.framework and WHP through the sessions of those hosts.

## A patch that does not apply

`build.sh` stops with the name of the patch:

    error: patches/0001-virtio-console-fill-queue.patch does not apply to Linux 7.4.1.

The job then fails, and GitHub sends the failure to the owners of the repository. Then do one of these:

- Port the patch to the new code. Keep the header, and measure the gain again on the new kernel.
- Drop the patch when upstream has the same fix, or when the new code has no cost to cut. Remove the file in the same PR, and say in the commit message which upstream commit or version made it needless.

Each patch has its measured gain in its header. A patch with no gain on the current kernel goes. Only the agent of the GPL wall reads kernel source and ports the patches.
