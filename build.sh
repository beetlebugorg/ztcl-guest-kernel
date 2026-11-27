#!/bin/sh
# Builds the guest kernel of ztcl::vm: tinyconfig, then config/*.fragment
# in order, then patches/*.patch on the release archive.
# Output in OUT (default out/): bzImage, vmlinux, System.map, kernel.config,
# SHA256SUMS. JOBS sets the make jobs.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
KERNEL=${KERNEL:-6.12.119}
KERNEL_SHA=143b287965acb9e270095b95894e59e2eba306d7e1f6b260d4ba74fca70c0333
work=${WORK:-$here/work}
out=${OUT:-$here/out}
jobs=${JOBS:-$(nproc)}
# A fixed time, user, and host give the same bytes on each build.
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1767225600}
export KBUILD_BUILD_TIMESTAMP="@$SOURCE_DATE_EPOCH"
export KBUILD_BUILD_USER=ztcl KBUILD_BUILD_HOST=ztcl KBUILD_BUILD_VERSION=1
mkdir -p "$work" "$out"
cd "$work"
tar=linux-$KERNEL.tar.xz
[ -f "$tar" ] || curl -fsSLO "https://cdn.kernel.org/pub/linux/kernel/v6.x/$tar"
echo "$KERNEL_SHA  $tar" | sha256sum -c
rm -rf "linux-$KERNEL"
tar xf "$tar"
cd "linux-$KERNEL"
for p in "$here"/patches/*.patch; do
    [ -f "$p" ] || continue
    echo "patch: $(basename "$p")"
    patch -p1 -s < "$p"
done
make -s tinyconfig
./scripts/kconfig/merge_config.sh -m .config "$here"/config/*.fragment >/dev/null
make -s olddefconfig
# Each option of the fragments that the merge dropped.
cat "$here"/config/*.fragment | grep -v '^#' | grep . | while read -r opt; do
    grep -qx "$opt" .config || echo "missing: $opt"
done
cat "$here"/config/*.fragment | grep '^# CONFIG_.* is not set' | while read -r opt; do
    grep -qx "$opt" .config || echo "set: $opt"
done
make -s -j"$jobs" bzImage
cp arch/x86/boot/bzImage System.map "$out/"
strip -o "$out/vmlinux" vmlinux
cp .config "$out/kernel.config"
cd "$out"
sha256sum bzImage vmlinux kernel.config > SHA256SUMS
cat SHA256SUMS
