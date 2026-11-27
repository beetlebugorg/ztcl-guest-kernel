#!/bin/sh
# bench.sh ZTCL DIR N NAME=KERNEL...: times each kernel file of DIR on
# KVM with the verity root DIR/root.img and the command line of
# DIR/x86_64.json, round robin, N boots each. Prints a Markdown table.
set -eu
ztcl=$1 dir=$2 n=$3
shift 3
here=$(cd "$(dirname "$0")" && pwd)
cmd=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["cmdline"])' "$dir/x86_64.json")
t=$(mktemp -p "$dir" bench.XXXXXX.tcl)
{
    printf 'set n %s\nset configs {\n' "$n"
    for nk in "$@"; do
        printf '{%s} {%s} {%s} {-disk root.img}\n' "${nk%%=*}" "${nk#*=}" "$cmd"
    done
    printf '}\n'
    cat "$here/bench.tcl"
} > "$t"
cd "$dir"
"$ztcl" --root . --allow vm,file,channels,clock "$(basename "$t")"
rm -f "$t"
