# Run the bare-metal applications in upstream QEMU's xlnx-zcu102 machine (a
# generic ZynqMP; the board differences that matter here, UART1 as the console
# and DDR size, are handled below): hello_world_a53, _a53_1 and _a53_2 on
# A53#0-#2 and hello_world_r5 on R5#0, all in one QEMU instance.
#
# QEMU doesn't model the R5 TCMs, so every core sees the same memory and
# hello_world_r5 (linked into TCM at 0x0-0x3FFFF) is loaded into DDR at 0x0.
# hello_world_a53 is linked at 0x40000 so the two don't overlap.
#
# Build the applications first (Vitis IDE or `vitis -s build.py` in sw/);
# these targets use the existing ELFs and do not rebuild them.
#
# Known QEMU limitation: its TTC model has 16-bit counters (32-bit on real
# ZynqMP), so sleep() on the R5 (which uses TTC3) returns almost immediately
# and hello_world_r5 prints in a tight loop. The A53s use the generic timer
# and are unaffected.

QEMU        ?= qemu-system-aarch64
CROSS32     ?= arm-none-eabi-
READELF     ?= readelf
TELNET_PORT ?= 5678

ELF_A53_0 := sw/hello_world_a53/build/hello_world_a53.elf
ELF_A53_1 := sw/hello_world_a53_1/build/hello_world_a53_1.elf
ELF_A53_2 := sw/hello_world_a53_2/build/hello_world_a53_2.elf
ELF_R5    := sw/hello_world_r5/build/hello_world_r5.elf
BOOT      := build/qemu/boot.elf

entry = $$($(READELF) -h $(1) | awk '/Entry point/ {print $$4}')

# secure=on,virtualization=on: start the A53s at EL3, which the BSPs expect.
# UART1 (second -serial) is the console; UART0 is unused.
# CPUs 0-3 are the A53s and CPU 4 is R5#0. boot-cpu makes R5#0 the only CPU
# running at reset; it starts at the boot stub, which releases A53#0-#2 at
# their entry points and jumps to hello_world_r5. A53#3 stays powered off.
# The application ELFs are only copied into memory.
QEMU_ARGS := -M xlnx-zcu102,secure=on,virtualization=on -m 2G -nographic \
             -serial null \
             -serial telnet:localhost:$(TELNET_PORT),server=on,wait=off \
             -smp 5 -global 'xlnx-zynqmp.boot-cpu=rpu-cpu[0]' \
             -device loader,file=$(ELF_A53_0) \
             -device loader,file=$(ELF_A53_1) \
             -device loader,file=$(ELF_A53_2) \
             -device loader,file=$(ELF_R5) \
             -device loader,file=$(BOOT),cpu-num=4

.PHONY: qemu qemu_debug

# In another shell: telnet localhost 5678
# Quit qemu: (qemu) quit
# Quit telnet: Ctrl + ] -> telnet> quit
# Output printed before telnet connects is lost (wait=off); use qemu_debug to
# start halted instead.
qemu: $(BOOT)
	$(QEMU) $(QEMU_ARGS)

# Same as qemu, but halts at startup and waits for GDB on localhost:1234
# (replace -s with -gdb tcp:localhost:<PORT> to use a different port).
# QEMU's GDB stub shows each CPU cluster as a process: process 1 is the A53s
# (thread 1.1 = A53#0, 1.2 = A53#1, ...) and process 2 is the R5s.
# schedule-multiple on makes continue resume both clusters; without it,
# continuing the A53s alone would wait forever, since the R5 releases them.
# After attaching the R5, detach and re-attach the A53s (process 1): otherwise
# GDB handles the A53s' breakpoint hits as silent stops and never reports them
# whenever inferior 2 is selected at the first continue (seen with GDB 16).
# VS Code's cppdbg always selects the thread of the most recent stop, so the
# A53 attach must come last. The re-attach gives the A53s new global thread
# IDs, so VS Code lists them as threads 6-9 (A53#0 = 6); the R5 stays thread 5.
# Use the "QEMU All Cores Debug" configuration in .vscode/launch.json, or:
#   gdb-multiarch -q sw/hello_world_a53/build/hello_world_a53.elf
#   (gdb) add-symbol-file sw/hello_world_a53_1/build/hello_world_a53_1.elf
#   (gdb) add-symbol-file sw/hello_world_a53_2/build/hello_world_a53_2.elf
#   (gdb) target extended-remote localhost:1234
#   (gdb) set schedule-multiple on
#   (gdb) set scheduler-locking step
#   (gdb) add-inferior
#   (gdb) inferior 2
#   (gdb) file sw/hello_world_r5/build/hello_world_r5.elf
#   (gdb) attach 2
#   (gdb) inferior 1
#   (gdb) detach
#   (gdb) attach 1
#   (gdb) break main
#   (gdb) continue
# In another shell: telnet localhost 5678
qemu_debug: $(BOOT)
	$(QEMU) $(QEMU_ARGS) -S -s

# Rebuilt whenever an application ELF changes, since the entry points are baked in.
$(BOOT): qemu/boot.S $(ELF_A53_0) $(ELF_A53_1) $(ELF_A53_2) $(ELF_R5)
	@mkdir -p $(dir $@)
	$(CROSS32)gcc -mcpu=cortex-r5 -nostdlib -g \
		-Wl,-Ttext=0xFFFC0000 -Wl,--build-id=none \
		-DA53_0_ENTRY=$(call entry,$(ELF_A53_0)) \
		-DA53_1_ENTRY=$(call entry,$(ELF_A53_1)) \
		-DA53_2_ENTRY=$(call entry,$(ELF_A53_2)) \
		-DR5_ENTRY=$(call entry,$(ELF_R5)) \
		-o $@ $<

$(ELF_A53_0) $(ELF_A53_1) $(ELF_A53_2) $(ELF_R5):
	$(error $@ not found; build the applications in Vitis first)
