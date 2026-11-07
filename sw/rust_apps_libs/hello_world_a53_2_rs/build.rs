use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo::rustc-check-cfg=cfg(xilrs_other_target)");
    if env::var("TARGET").unwrap() != "aarch64-unknown-none" {
        // Built for the other core's target, e.g. by rust-analyzer, which checks the
        // whole workspace for one target (rust-analyzer.cargo.target): main.rs then
        // compiles to a stub, and nothing is linked for the wrong core
        println!("cargo::rustc-cfg=xilrs_other_target");
        return;
    }

    // From xil-a53-amp-sys (`links = "xil_a53_amp"`): the BSP's Xilinx.spec swaps GCC's
    // startup files for the ones the BSP's boot code expects, like in Vitis
    let specs = env::var("DEP_XIL_A53_AMP_SPECS").unwrap();
    println!("cargo:rustc-link-arg-bins=-specs={specs}");

    // This app's linker script (memory map), copied from the C application's
    // hello_world_a53_2/src/lscript.ld
    let linker_script = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap()).join("linker.ld");
    println!("cargo:rerun-if-changed={}", linker_script.display());
    println!("cargo:rustc-link-arg-bins=-Wl,-T,{}", linker_script.display());
}
