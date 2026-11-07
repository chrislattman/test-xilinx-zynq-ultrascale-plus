# Bare metal software applications

## QEMU

The applications can also run in upstream QEMU's `xlnx-zcu102` machine (see `Makefile` for details). `make qemu` runs all four (A53#0-#2 and R5#0) in one QEMU instance, and `make qemu_debug` does the same but halts and waits for GDB on `localhost:1234` (use the "QEMU All Cores Debug" configuration in `.vscode/launch.json`). UART output (UART1) is on `telnet localhost 5678`.

QEMU doesn't model the R5's TCM. On hardware, the R5's address 0x0 is its private TCM, but in QEMU every core sees the same memory, so `hello_world_r5` (linked into TCM at 0x00000-0x3FFFF) is loaded into DDR at 0x0. For that reason `hello_world_a53` is linked at 0x40000 (256 KB) instead of 0x0, so the two don't overlap. On hardware this just leaves the first 256 KB of DDR unused.

QEMU's TTC model also has 16-bit counters (32-bit on real ZynqMP), so `sleep()` on the R5, which uses TTC3, returns almost immediately and `hello_world_r5` posts messages in a tight loop, so A53#0 prints up to 8 R5 messages a second. The A53s use the generic timer and are unaffected.

## Rust applications

`sw/` is also a Cargo workspace with `no_std` Rust ports of the four applications (`sw/rust_apps_libs/`), built on bindgen bindings to the three standalone BSPs (`sw/rust_platform/`, every header in each BSP's `include/`):

| Application crate | Port of | BSP crate (domain) | Rust target |
|---|---|---|---|
| `hello-world-a53-rs` | `hello_world_a53` | `xil-a53-0-sys` (`standalone_psu_cortexa53_0`) | `aarch64-unknown-none` |
| `hello-world-a53-1-rs` | `hello_world_a53_1` | `xil-a53-amp-sys` (`standalone_a53_amp`) | `aarch64-unknown-none` |
| `hello-world-a53-2-rs` | `hello_world_a53_2` | `xil-a53-amp-sys` (`standalone_a53_amp`) | `aarch64-unknown-none` |
| `hello-world-r5-rs` | `hello_world_r5` | `xil-r5-0-sys` (`standalone_psu_cortexr5_0`) | `armv7r-none-eabihf` |

Build the platform in Vitis first (`vitis -s build.py --no-apps` in `sw/` builds just the platform, skipping the C applications), then source the Vitis environment and run `cargo build-a53` and `cargo build-r5` from `sw/`. The ELFs are in `sw/target/<rust target>/<debug|release>/`, and each app has its own `linker.ld`, a copy of its C counterpart's `lscript.ld`.

To run them in QEMU, point the `Makefile` at them (same for `qemu_debug`):

```
make qemu ELF_A53_0=sw/target/aarch64-unknown-none/debug/hello-world-a53-rs \
          ELF_A53_1=sw/target/aarch64-unknown-none/debug/hello-world-a53-1-rs \
          ELF_A53_2=sw/target/aarch64-unknown-none/debug/hello-world-a53-2-rs \
          ELF_R5=sw/target/armv7r-none-eabihf/debug/hello-world-r5-rs
```

To debug them, use the `Rust: ...` configurations in `.vscode/launch.json` (Native Debug extension with `rust-gdb`). On the board, run `xsdb vscode_debug.tcl rust` first (combine with `split` as needed), which loads the Rust ELFs instead of the C ones. In QEMU, use `make qemu_debug` with the overrides above.

ZU+ specifics:

- There are two architectures and stable Cargo can't pin a package to a target, so there's no default target, only the `build-a53`/`build-r5` aliases in `sw/.cargo/config.toml`
- rust-analyzer analyzes the workspace for one target at a time (`rust-analyzer.cargo.target` in `.vscode/settings.json`, set to `aarch64-unknown-none`). Switch it to `armv7r-none-eabihf` for R5 code. A crate built for the other core's target compiles to an empty crate (or, for an app, a stub) so this doesn't error
- The cores don't share peripherals: only A53#0 prints (UART1). A53#1, A53#2 and R5#0 post their messages to a mailbox in its own 2 MB DDR block at `0x30000000` (`sw/shared_mem/shared_mem.h` for C, `sw/rust_apps_libs/shared_mem` for Rust), and A53#0 prints them every second
    - Every core maps that block non-cacheable, because the R5 isn't cache-coherent with the A53s, and it holds only fixed-width fields, because the A53s are 64-bit and the R5 is 32-bit
    - QEMU doesn't model caches, so it can't catch a wrong cache attribute; only hardware can
