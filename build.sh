#!/bin/sh
# Builds the guest kernel of ztcl::vm for ARCH (x86_64, the default, or
# arm64): tinyconfig, then config/10-base, config/20-ARCH (if any),
# config/30-boot, and config/40-ARCH-boot, on the release archive with
# patches/*.patch.
# Output in OUT (default out/ARCH): the kernel (bzImage and vmlinux on
# x86-64, Image on arm64), System.map, kernel.config, and SHA256SUMS.
# JOBS sets the make jobs. LLVM=1 builds with clang and ld.lld, for
# an arm64 kernel on an x86-64 host.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
KERNEL=${KERNEL:-7.3.6}
KERNEL_SHA=8183d475a76a0faffa92d6cd500af421f589dfd0300a0f1060bb875e11d45723
arch=${ARCH:-x86_64}
work=${WORK:-$here/work}
out=${OUT:-$here/out/$arch}
jobs=${JOBS:-$(nproc)}
llvm=${LLVM:+LLVM=$LLVM}
case $arch in
    x86_64) karch=x86 target=bzImage ;;
    arm64) karch=arm64 target=Image ;;
    *) echo "ARCH must be x86_64 or arm64" >&2; exit 2 ;;
esac
frags="$here/config/10-base.fragment"
[ -f "$here/config/20-$arch.fragment" ] && frags="$frags $here/config/20-$arch.fragment"
frags="$frags $here/config/30-boot.fragment $here/config/40-$arch-boot.fragment"
# A fixed time, user, and host give the same bytes on each build.
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1767225600}
export KBUILD_BUILD_TIMESTAMP="@$SOURCE_DATE_EPOCH"
export KBUILD_BUILD_USER=ztcl KBUILD_BUILD_HOST=ztcl KBUILD_BUILD_VERSION=1
mkdir -p "$work" "$out"
cd "$work"
tar=linux-$KERNEL.tar.xz
[ -f "$tar" ] || curl -fsSLO "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL%%.*}.x/$tar"
echo "$KERNEL_SHA  $tar" | sha256sum -c
src=linux-$KERNEL-$arch
rm -rf "$src" "linux-$KERNEL"
tar xf "$tar"
mv "linux-$KERNEL" "$src"
cd "$src"
for p in "$here"/patches/*.patch; do
    [ -f "$p" ] || continue
    echo "patch: $(basename "$p")"
    if ! patch -p1 -s --dry-run < "$p" > /dev/null; then
        echo "error: patches/$(basename "$p") does not apply to Linux $KERNEL." >&2
        echo "Port the patch or drop it, as UPDATING.md says." >&2
        exit 1
    fi
    patch -p1 -s < "$p"
done
# shellcheck disable=SC2086
make -s ARCH=$karch $llvm tinyconfig
# shellcheck disable=SC2086
ARCH=$karch ./scripts/kconfig/merge_config.sh -m .config $frags >/dev/null
# shellcheck disable=SC2086
make -s ARCH=$karch $llvm olddefconfig
# Each option of the fragments that the merge dropped.
# shellcheck disable=SC2086
cat $frags | grep -v '^#' | grep . | while read -r opt; do
    grep -qx "$opt" .config || echo "missing: $opt"
done
# shellcheck disable=SC2086
make -s ARCH=$karch $llvm -j"$jobs" $target
cp System.map .config "$out/"
mv "$out/.config" "$out/kernel.config"
if [ "$arch" = x86_64 ]; then
    cp arch/x86/boot/bzImage "$out/"
    strip -o "$out/vmlinux" vmlinux
    sums="bzImage vmlinux"
else
    cp arch/arm64/boot/Image "$out/"
    sums=Image
fi
cd "$out"
# shellcheck disable=SC2086
sha256sum $sums kernel.config > SHA256SUMS
cat SHA256SUMS
