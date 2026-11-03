# Run the bare-metal applications in upstream QEMU's xlnx-zcu102 machine (a
# generic ZynqMP; the board differences that matter here, UART1 as the console
# and DDR size, are handled below).
#
#   qemu / qemu_debug        hello_world_a53, _a53_1 and _a53_2 on A53#0-#2
#   qemu_r5 / qemu_r5_debug  hello_world_r5 on R5#0
#
# The A53 and R5 applications can't run in the same QEMU instance: QEMU doesn't
# model the R5 TCMs, so hello_world_r5 (linked into TCM at 0x0) would land on
# top of hello_world_a53 in DDR at 0x0.
#
# Build the applications first (Vitis IDE or `vitis -s build.py` in sw/);
# these targets use the existing ELFs and do not rebuild them.
#
# Known QEMU limitation: its TTC model has 16-bit counters (32-bit on real
# ZynqMP), so sleep() on the R5 (which uses TTC3) returns almost immediately
# and hello_world_r5 prints in a tight loop. The A53s use the generic timer
# and are unaffected.

QEMU        ?= qemu-system-aarch64
CROSS64     ?= aarch64-linux-gnu-
CROSS32     ?= arm-none-eabi-
READELF     ?= readelf
TELNET_PORT ?= 5678

ELF_A53_0 := sw/hello_world_a53/build/hello_world_a53.elf
ELF_A53_1 := sw/hello_world_a53_1/build/hello_world_a53_1.elf
ELF_A53_2 := sw/hello_world_a53_2/build/hello_world_a53_2.elf
ELF_R5    := sw/hello_world_r5/build/hello_world_r5.elf
A53_BOOT  := build/qemu/a53_boot.elf
R5_BOOT   := build/qemu/r5_boot.elf

entry = $$($(READELF) -h $(1) | awk '/Entry point/ {print $$4}')

# secure=on,virtualization=on: start the A53s at EL3, which the BSPs expect.
# UART1 (second -serial) is the console; UART0 is unused.
QEMU_COMMON := -M xlnx-zcu102,secure=on,virtualization=on -m 2G -nographic \
               -serial null \
               -serial telnet:localhost:$(TELNET_PORT),server=on,wait=off

# The application ELFs are only copied into memory. A53#0 starts at the boot
# stub, which releases A53#1/#2 at their entry points and jumps to
# hello_world_a53. A53#3 stays powered off.
QEMU_A53 := $(QEMU_COMMON) -smp 4 \
            -device loader,file=$(ELF_A53_0) \
            -device loader,file=$(ELF_A53_1) \
            -device loader,file=$(ELF_A53_2) \
            -device loader,file=$(A53_BOOT),cpu-num=0

# CPUs 0-3 are the A53s and CPU 4 is R5#0. boot-cpu makes R5#0 the only CPU
# running at reset (the A53s stay powered off).
QEMU_R5 := $(QEMU_COMMON) -smp 5 -global 'xlnx-zynqmp.boot-cpu=rpu-cpu[0]' \
           -device loader,file=$(ELF_R5) \
           -device loader,file=$(R5_BOOT),cpu-num=4

.PHONY: qemu qemu_debug qemu_r5 qemu_r5_debug

# In another shell: telnet localhost 5678
# Quit qemu: (qemu) quit
# Quit telnet: Ctrl + ] -> telnet> quit
# Output printed before telnet connects is lost (wait=off); use qemu_debug to
# start halted instead.
qemu: $(A53_BOOT)
	$(QEMU) $(QEMU_A53)

# Same as qemu, but halts at startup and waits for GDB on localhost:1234
# (replace -s with -gdb tcp:localhost:<PORT> to use a different port).
# The A53s are threads of one inferior (thread 1 = A53#0, 2 = A53#1, ...).
# Use the "QEMU A53#0 + A53#1 + A53#2 Debug" configuration in
# .vscode/launch.json, or:
#   gdb-multiarch -q sw/hello_world_a53/build/hello_world_a53.elf
#   (gdb) add-symbol-file sw/hello_world_a53_1/build/hello_world_a53_1.elf
#   (gdb) add-symbol-file sw/hello_world_a53_2/build/hello_world_a53_2.elf
#   (gdb) target remote localhost:1234
#   (gdb) set scheduler-locking step
#   (gdb) break main
#   (gdb) continue
# In another shell: telnet localhost 5678
qemu_debug: $(A53_BOOT)
	$(QEMU) $(QEMU_A53) -S -s

# Same as qemu, for hello_world_r5. In another shell: telnet localhost 5678
qemu_r5: $(R5_BOOT)
	$(QEMU) $(QEMU_R5)

# Same as qemu_r5, but halts at startup and waits for GDB on localhost:1234.
# QEMU's GDB stub shows the R5 cluster as a second process, so attach to it.
# Use the "QEMU R5 Debug" configuration in .vscode/launch.json, or:
#   gdb-multiarch -q
#   (gdb) target extended-remote localhost:1234
#   (gdb) add-inferior
#   (gdb) inferior 2
#   (gdb) file sw/hello_world_r5/build/hello_world_r5.elf
#   (gdb) attach 2
#   (gdb) break main
#   (gdb) continue
# In another shell: telnet localhost 5678
qemu_r5_debug: $(R5_BOOT)
	$(QEMU) $(QEMU_R5) -S -s

# Rebuilt whenever an application ELF changes, since the entry points are baked in.
$(A53_BOOT): qemu/a53_boot.S $(ELF_A53_0) $(ELF_A53_1) $(ELF_A53_2)
	@mkdir -p $(dir $@)
	$(CROSS64)gcc -nostdlib -ffreestanding -static -g \
		-Wl,-Ttext=0xFFFC0000 -Wl,--build-id=none \
		-DA53_0_ENTRY=$(call entry,$(ELF_A53_0)) \
		-DA53_1_ENTRY=$(call entry,$(ELF_A53_1)) \
		-DA53_2_ENTRY=$(call entry,$(ELF_A53_2)) \
		-o $@ $<

$(R5_BOOT): qemu/r5_boot.S $(ELF_R5)
	@mkdir -p $(dir $@)
	$(CROSS32)gcc -mcpu=cortex-r5 -nostdlib -g \
		-Wl,-Ttext=0xFFFC0000 -Wl,--build-id=none \
		-DR5_ENTRY=$(call entry,$(ELF_R5)) \
		-o $@ $<

$(ELF_A53_0) $(ELF_A53_1) $(ELF_A53_2) $(ELF_R5):
	$(error $@ not found; build the applications in Vitis first)
