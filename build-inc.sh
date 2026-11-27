#!/bin/sh
# Incremental build in work/ with the current fragments; output in $1.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
cd "${TREE:-$here/work/linux-6.12.119}"
export SOURCE_DATE_EPOCH=1767225600 KBUILD_BUILD_TIMESTAMP=@1767225600 KBUILD_BUILD_USER=ztcl KBUILD_BUILD_HOST=ztcl KBUILD_BUILD_VERSION=1
make -s tinyconfig
./scripts/kconfig/merge_config.sh -m .config "$here"/config/*.fragment >/dev/null
make -s olddefconfig
make -s -j"${JOBS:-3}" bzImage 2>&1 | grep -v objtool || true
mkdir -p "$1"; cp arch/x86/boot/bzImage System.map "$1/"; strip -o "$1/vmlinux" vmlinux; cp .config "$1/kernel.config"
