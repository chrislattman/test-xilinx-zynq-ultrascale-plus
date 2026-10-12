connect
bpremove -all
targets 8
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
dow ./sw/hello_world_r5/build/hello_world_r5.elf

targets -set -nocase -filter {name =~ "*A53*#0" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
rst -processor
dow ./sw/hello_world_a53/build/hello_world_a53.elf

targets -set -nocase -filter {name =~ "*A53*#1" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
rst -processor
dow ./sw/hello_world_a53_1/build/hello_world_a53_1.elf

targets -set -nocase -filter {name =~ "*A53*#2" && jtag_cable_name =~ "Avnet USB-to-JTAG/UART Pod V1 1234-oj1A" && jtag_device_ctx=="jsn-USB-to-JTAG/UART Pod V1-1234-oj1A-5ba00477-0"}
rst -processor
dow ./sw/hello_world_a53_2/build/hello_world_a53_2.elf
configparams force-mem-access 0
