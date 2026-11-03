# Bare Metal C Zynq UltraScale+ Example

This project demonstrates hello world A53 and R5 applications.

A note on DDR memory: the first 4GB is for the PS. The remaining memory is reserved for peripherals and the PL.

## QEMU

The applications can also run in upstream QEMU's `xlnx-zcu102` machine (see `Makefile` for details):

- `make qemu` / `make qemu_debug`: the three A53 applications on A53#0-#2
- `make qemu_r5` / `make qemu_r5_debug`: the R5 application on R5#0

UART output (UART1) is on `telnet localhost 5678`, and the `_debug` targets wait for GDB on `localhost:1234` (use the "QEMU ..." configurations in `.vscode/launch.json`).

The A53 and R5 applications run in separate QEMU instances because QEMU doesn't model the R5's TCM. On hardware, the R5's address 0x0 is its private TCM, but in QEMU every core sees the same memory, so `hello_world_r5` (linked into TCM at 0x0) would be loaded on top of `hello_world_a53` (linked into DDR at 0x0).

QEMU's TTC model also has 16-bit counters (32-bit on real ZynqMP), so `sleep()` on the R5, which uses TTC3, returns almost immediately and `hello_world_r5` prints in a tight loop. The A53s use the generic timer and are unaffected.
