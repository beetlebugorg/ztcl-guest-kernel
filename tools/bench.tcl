# The boot times of the kernels of `configs`, round robin, `n` boots of
# each: guest boot to agent listen and start to answer, best and
# median, in ms. bench.sh writes the two variables before this file.
proc q {l p} { set s [lsort -real $l]; lindex $s [expr {int(([llength $s] - 1) * $p)}] }
set res {}
for {set i 0} {$i < $n} {incr i} {
    set k 0
    foreach {name kern cmd media} $configs {
        set vm [ztcl::vm create -kernel $kern {*}$media -cmdline $cmd -memory 64]
        set t0 [clock microseconds]
        ztcl::vm start $vm
        set ch [ztcl::vm vsock $vm 1025]
        binary scan [read $ch 16] ww main listen
        set t2 [clock microseconds]
        close $ch
        ztcl::vm delete $vm
        dict lappend res $k,a [expr {($t2 - $t0) / 1000.0}]
        dict lappend res $k,b [expr {$listen / 1e6}]
        incr k
    }
}
puts "| Kernel | listen, best | listen, median | answer, best | answer, median |"
puts "|---|---|---|---|---|"
set k 0
foreach {name kern cmd media} $configs {
    set a [dict get $res $k,a]; set b [dict get $res $k,b]
    puts [format "| %s | %.2f | %.2f | %.2f | %.2f |" $name [q $b 0] [q $b 0.5] [q $a 0] [q $a 0.5]]
    incr k
}
