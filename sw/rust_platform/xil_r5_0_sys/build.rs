use xil_bsp_build::{Arch, Bsp};

fn main() {
    Bsp {
        arch: Arch::R5,
        default_dir: "../../platform/psu_cortexr5_0/standalone_psu_cortexr5_0/bsp",
        dir_env: "XIL_R5_0_BSP_DIR",
        // Beyond -DSDT and the arch's own; must match TOOLCHAIN_C_FLAGS in the BSP's *_toolchain.cmake
        defines: &[],
    }
    .build();
}
