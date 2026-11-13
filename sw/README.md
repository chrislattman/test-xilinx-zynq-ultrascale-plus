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

Build the platform in Vitis first (`vitis -s build.py` in `sw/` builds it along with the C applications), then source the Vitis environment and run `cargo build-a53` and `cargo build-r5` from `sw/`. The ELFs are in `sw/target/<rust target>/<debug|release>/`, and each app has its own `linker.ld`, a copy of its C counterpart's `lscript.ld` (except that `hello-world-r5-rs` starts `.text` at 0x20000, see below).

To run them in QEMU, point the `Makefile` at them (same for `qemu_debug`):

```
make qemu ELF_A53_0=sw/target/aarch64-unknown-none/debug/hello-world-a53-rs \
          ELF_A53_1=sw/target/aarch64-unknown-none/debug/hello-world-a53-1-rs \
          ELF_A53_2=sw/target/aarch64-unknown-none/debug/hello-world-a53-2-rs \
          ELF_R5=sw/target/armv7r-none-eabihf/debug/hello-world-r5-rs
```

To debug them, use the `Rust: ...` configurations in `.vscode/launch.json` (Native Debug extension with `rust-gdb`). On the board, run `xsdb vscode_debug.tcl rust` first (combine with `split` as needed), which loads the Rust ELFs instead of the C ones. In QEMU, use `make qemu_debug` with the overrides above.

### Debugging the Rust applications in Vitis

`system_project_rust` is a copy of `system_project` whose launch configuration (`system_project_rust/_ide/launch.json`) downloads the Rust ELFs instead of the C ones. Run `cargo build-a53` and `cargo build-r5` from `sw/` first, then launch `system_project_rust_app_hw_1` in Vitis as usual. Debugging works the same as with the C applications (TCF Debug Adapter, per-core run control, cross-trigger option).

- Vitis doesn't build the Rust applications. Building `system_project_rust` only builds the C components it lists (a system project needs Vitis components), so run both `cargo build-*` aliases before every launch or Vitis loads stale ELFs
- The `elfFile` paths point straight at the Cargo outputs (`${workspaceFolder}/target/aarch64-unknown-none/debug/hello-world-a53-rs`, `hello-world-a53-1-rs`, `hello-world-a53-2-rs` and `${workspaceFolder}/target/armv7r-none-eabihf/debug/hello-world-r5-rs`). The launch accepts them without a `.elf` extension, but the launch editor's "add ELF" dialog doesn't, so edit `launch.json` directly to change them (e.g. to the `release` builds)
- The precompiled `core` library's debug info points at `/rustc/<commit hash>/library/...` (where Rust was built), so stopping in or stepping into `core` code gives "Could not find the source file". The `pathMap` in `launch.json` maps that prefix to the local `rust-src` copy (`~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/src/rust`). The hash changes with every Rust release (`rust-toolchain.toml` follows `stable`), so after a `rustup update`, replace it with the new `commit-hash` from `rustc -vV`
- `hello-world-r5-rs`'s `linker.ld` starts `.text` (and everything after it) at 0x20000, the BTCM, instead of right after the vectors. When `--gc-sections` drops an unused function (thousands of them, mostly from the precompiled `core` library), GNU ld keeps its debug info but with address 0, so with code near 0 every debugger (hw_server, GDB, `llvm-dwarfdump --lookup`) maps those addresses to the dropped functions' source. Vitis then showed R5#0 stopped at `core/src/fmt/num.rs:446` when it was actually at `main`. The A53 applications start at 0x40000 or higher, so they aren't affected. 0x20000 is valid in both lockstep and split mode, and the largest dropped function is ~13 KB, so only the vectors and boot code (`_boot`) still show the wrong source. If the application grows beyond the BTCM's 64 KB in split mode (it ends at about 0x2a600 now), move `.text` back down and accept the wrong line info, or strip the dead DWARF after linking (`llvm-dwarfutil --garbage-collection`, which also drops some globals' debug info)
- Line breakpoints, stepping and call stacks work in Rust code, and C-like enums show by name. Values aren't pretty-printed, though: an `AtomicU32` shows as `{v={value={__0=0x9}}}`. Use the `rust-gdb` configurations above when you need readable Rust values
- Unlike `vscode_debug.tcl`, a Vitis launch doesn't zero the R5's TCMs (see the ECC comment in `vscode_debug.tcl`) or clear the mailbox's `ready` word at `0x30000000` (this applies to the C applications too). The Rust R5 application has hit the TCM ECC abort before (a byte or halfword write to a never-written TCM word ends in `Xil_DataAbortHandler`), so if R5#0 aborts under Vitis, use `vscode_debug.tcl` instead. Not yet tested on the board with `system_project_rust`
- `system_project_rust` was created with the Vitis Python API (`create_sys_project`, then `add_component` for `hello_world_r5`, `hello_world_a53` and `hello_world_a53_1`, which requires the Vitis IDE to be closed). `add_component` rejects `hello_world_a53_2` ("does not have a matching domain") because its domain, `standalone_a53_amp`, belongs to `psu_cortexa53_1`, so it was added to `externalComponentRefs` in `vitis-sys.json` by hand, matching `system_project`. Its `_ide/` contents (bitstream, `psinit/psu_init.tcl`, `hwspec.checksum`) were copied from `system_project`. If the hardware design changes, copy them again

ZU+ specifics:

- There are two architectures and stable Cargo can't pin a package to a target, so there's no default target, only the `build-a53`/`build-r5` aliases in `sw/.cargo/config.toml`
- rust-analyzer analyzes the workspace for one target at a time (`rust-analyzer.cargo.target` in `.vscode/settings.json`, set to `aarch64-unknown-none`). Switch it to `armv7r-none-eabihf` for R5 code. A crate built for the other core's target compiles to an empty crate (or, for an app, a stub) so this doesn't error
- The Rust ports predate the C applications' memory isolation: they don't unmap the other cores' private DDR (`unmap_blocks()`/`unmap_a53_ddr()` in `sw/shared_mem/shared_mem.h`), so a stray access from Rust isn't caught

## Notes

- The cores don't share peripherals: only A53#0 prints (UART1). A53#1, A53#2 and R5#0 post their messages to a mailbox in its own 2 MB DDR block at `0x30000000` (`sw/shared_mem/shared_mem.h` for C, `sw/rust_apps_libs/shared_mem` for Rust), and A53#0 prints them every second
    - Every core maps that block non-cacheable, because the R5 isn't cache-coherent with the A53s, and it holds only fixed-width fields, because the A53s are 64-bit and the R5 is 32-bit
    - QEMU doesn't model caches, so it can't catch a wrong cache attribute; only hardware can
