# "xsdb vscode_debug.tcl rust" loads the Rust applications (sw/rust_apps_libs,
# debug build) instead of the C ones; use the "Rust: ..." launch configurations then.
# Combine with "split" as needed, e.g. "xsdb vscode_debug.tcl rust split".
if {[info exists argv] && [lsearch -exact $argv rust] >= 0} {
    set elf_a53_0 ./sw/target/aarch64-unknown-none/debug/hello-world-a53-rs
    set elf_a53_1 ./sw/target/aarch64-unknown-none/debug/hello-world-a53-1-rs
    set elf_a53_2 ./sw/target/aarch64-unknown-none/debug/hello-world-a53-2-rs
    set elf_r5    ./sw/target/armv7r-none-eabihf/debug/hello-world-r5-rs
} else {
    set elf_a53_0 ./sw/hello_world_a53/build/hello_world_a53.elf
    set elf_a53_1 ./sw/hello_world_a53_1/build/hello_world_a53_1.elf
    set elf_a53_2 ./sw/hello_world_a53_2/build/hello_world_a53_2.elf
    set elf_r5    ./sw/hello_world_r5/build/hello_world_r5.elf
}

connect
bpremove -all
targets -set -nocase -filter {name =~"PSU*" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
rst
after 3000

targets -set -filter {jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && level==0 && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-14710093-0"}
fpga ./sw/system_project/_ide/bitstream/design_1_wrapper.bit
targets -set -nocase -filter {name =~"PSU*" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
catch {disable_pmu_gate}
targets -set -nocase -filter {name =~"APU*" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
loadhw -hw /home/chris/test-xilinx-zynq-ultrascale-plus/sw/platform/export/platform/hw/design_1_wrapper.xsa -mem-ranges [list {0x80000000 0xbfffffff} {0x400000000 0x5ffffffff} {0x1000000000 0x7fffffffff}]

configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
source /home/chris/opt/Xilinx/2025.2/Vitis/vitis-server/scripts/jtag_reg.tcl
targets -set -nocase -filter {name =~ "*A53*#0" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
rst -processor

dow ./sw/platform/export/platform/sw/boot/fsbl.elf
set bp_27_42_fsbl_bp [bpadd -addr &XFsbl_Exit]
con -block -timeout 60
bpremove $bp_27_42_fsbl_bp

# "xsdb vscode_debug.tcl split" runs the RPU in split mode instead of lockstep.
# Must happen while the R5s are still held in reset (same write as Vitis's enable_split_mode).
if {[lsearch -exact $argv split] >= 0} {
    targets -set -nocase -filter {name =~"RPU*" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
    mwr 0xff9a0000 0x208
}

targets -set -nocase -filter {name =~ "*R5*#0" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
rst -processor
# The R5 boot code turns on ECC checking for its TCMs, but nothing has initialized their
# ECC bits in this JTAG flow (in a boot image, the FSBL does it with XFsbl_TcmEccInit()
# before loading an R5 partition). A byte or halfword write to a TCM word that was never
# written then fails its ECC check and aborts. Zero the TCMs with full-word writes first:
# ATCM at 0x0 and BTCM at 0x20000, 128 KB each in lockstep (contiguous), 64 KB each in split
if {[lsearch -exact $argv split] >= 0} {
    mwr -force 0x0 0 0x4000
    mwr -force 0x20000 0 0x4000
} else {
    mwr -force 0x0 0 0x10000
}
dow $elf_r5

targets -set -nocase -filter {name =~ "*A53*#0" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
rst -processor
dow $elf_a53_0

targets -set -nocase -filter {name =~ "*A53*#1" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
rst -processor
dow $elf_a53_1

targets -set -nocase -filter {name =~ "*A53*#2" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
rst -processor
dow $elf_a53_2
# DDR keeps its contents across resets: clear the mailbox's ready word a previous run
# left at 0x30000000 (sw/shared_mem/shared_mem.h). Otherwise A53#1, A53#2 or R5#0 could
# see a stale MAILBOX_READY and post with stale ring counters before A53#0 clears them.
# All cores are halted at their entry points with caches off, so this reaches DDR
mwr 0x30000000 0
# bpadd -ct-input {16} -ct-output {0 8 24 32 40} -skip-on-step 0 -target-id all
configparams force-mem-access 0
