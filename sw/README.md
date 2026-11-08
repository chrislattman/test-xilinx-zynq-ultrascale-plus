# Bare metal software applications

## QEMU

The applications can also run in upstream QEMU's `xlnx-zcu102` machine (see `Makefile` for details). `make qemu` runs all four (A53#0-#2 and R5#0) in one QEMU instance, and `make qemu_debug` does the same but halts and waits for GDB on `localhost:1234` (use the "QEMU All Cores Debug" configuration in `.vscode/launch.json`). UART output (UART1) is on `telnet localhost 5678`.

QEMU doesn't model the R5's TCM. On hardware, the R5's address 0x0 is its private TCM, but in QEMU every core sees the same memory, so `hello_world_r5` (linked into TCM at 0x00000-0x3FFFF) is loaded into DDR at 0x0. For that reason `hello_world_a53` is linked at 0x40000 (256 KB) instead of 0x0, so the two don't overlap. On hardware this just leaves the first 256 KB of DDR unused.

QEMU's TTC model also has 16-bit counters (32-bit on real ZynqMP), so `sleep()` on the R5, which uses TTC3, returns almost immediately and `hello_world_r5` posts messages in a tight loop, so A53#0 prints up to 8 R5 messages a second. The A53s use the generic timer and are unaffected.

## Notes

- The cores don't share peripherals: only A53#0 prints (UART1). A53#1, A53#2 and R5#0 post their messages to a mailbox in its own 2 MB DDR block at `0x30000000` (`sw/shared_mem/shared_mem.h`), and A53#0 prints them every second
    - Every core maps that block non-cacheable, because the R5 isn't cache-coherent with the A53s, and it holds only fixed-width fields, because the A53s are 64-bit and the R5 is 32-bit
    - QEMU doesn't model caches, so it can't catch a wrong cache attribute; only hardware can
