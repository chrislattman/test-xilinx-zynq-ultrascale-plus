# Prints the hw_server jtag-port-filter value (the JTAG cable serial) for a
# connected Zynq board, identified by the FPGA on its scan chain.
#
#   xsdb find_jtag_filters.tcl --zynq      # Zynq 7000 (xc7z020)
#   xsdb find_jtag_filters.tcl --zynqmp    # Zynq UltraScale+ (xczu3)
#
# Only the serial is written to stdout, so it can be used as
#   hw_server -e "set jtag-port-filter $(xsdb find_jtag_filters.tcl --zynqmp)"
#
# A temporary unfiltered hw_server is started on a private port and killed
# afterwards, so the default port 3121 stays free. Run this before starting
# filtered hw_servers, since a cable already claimed by one may not show up.

# flag -> FPGA device name, exactly as reported by "jtag targets"
set boards {
    --zynq    xc7z020
    --zynqmp  xczu3
}
set port 3129

if {[llength $argv] != 1 || ![dict exists $boards [lindex $argv 0]]} {
    puts stderr "usage: xsdb find_jtag_filters.tcl --zynq|--zynqmp"
    exit 2
}
set fpga [dict get $boards [lindex $argv 0]]

set hw_server [file join $::env(XILINX_VITIS) bin hw_server]
exec $hw_server -s tcp:127.0.0.1:$port -p 0 >/dev/null 2>@1 &

proc stop_hw_server {} {
    catch {exec pkill -f "hw_server.*-s tcp:127.0.0.1:$::port"}
}

set connected 0
for {set i 0} {$i < 50} {incr i} {
    if {![catch {connect -url tcp:127.0.0.1:$port}]} {
        set connected 1
        break
    }
    after 200
}
if {!$connected} {
    puts stderr "error: could not connect to temporary hw_server on port $port"
    stop_hw_server
    exit 1
}

set serials {}
foreach t [jtag targets -target-properties] {
    if {[dict exists $t is_fpga] && [dict get $t is_fpga]
            && [dict get $t name] eq $fpga} {
        lappend serials [dict get $t jtag_cable_serial]
    }
}
disconnect
stop_hw_server

set serials [lsort -unique $serials]
if {[llength $serials] == 0} {
    puts stderr "error: no board with FPGA $fpga found"
    exit 1
}
if {[llength $serials] > 1} {
    puts stderr "error: more than one board with FPGA $fpga: $serials"
    exit 1
}
puts [lindex $serials 0]
