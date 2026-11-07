use xil_bsp_build::{Arch, Bsp};

fn main() {
    Bsp {
        arch: Arch::A53,
        default_dir: "../../platform/psu_cortexa53_0/standalone_psu_cortexa53_0/bsp",
        dir_env: "XIL_A53_0_BSP_DIR",
        // Beyond -DSDT and the arch's own; must match TOOLCHAIN_C_FLAGS in the BSP's *_toolchain.cmake
        defines: &[],
    }
    .build();
}
