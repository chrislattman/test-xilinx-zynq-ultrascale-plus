import argparse
import vitis

release_mode = False
parser = argparse.ArgumentParser()
parser.add_argument("--release", action="store_true")
args = parser.parse_args()
if args.release:
    release_mode = True

# A53#0 initializes the GIC distributor shared by the APU cores. A53#1-3 share
# one USE_AMP domain so they leave the distributor alone. The ELF isn't tied to
# a core (boot code reads MPIDR), so the debugger's download target decides
# which core runs it. The R5 has its own GIC and doesn't need USE_AMP.
bsp_flags = "-O2 -Wall -Wextra -fno-tree-loop-distribute-patterns"
if not release_mode:
    bsp_flags = "-O2 -g -Wall -Wextra -fno-tree-loop-distribute-patterns"
domains = {
    "standalone_psu_cortexa53_0": bsp_flags,
    "standalone_a53_amp": bsp_flags + " -DUSE_AMP=1",
    "standalone_psu_cortexr5_0": bsp_flags,
}

client = vitis.create_client()
client.update_workspace(".")

platform = client.get_component("platform")
for domain_name, flags in domains.items():
    domain_object = platform.get_domain(domain_name)
    domain_object.set_config(option="proc", param="proc_extra_compiler_flags", value=flags)
platform.build()

for app_name in ["hello_world_a53", "hello_world_a53_1", "hello_world_a53_2", "hello_world_r5"]:
    app = client.get_component(app_name)
    if release_mode:
        app.set_app_config(key="USER_COMPILE_DEBUG_LEVEL", values="")
        app.set_app_config(key="USER_COMPILE_OPTIMIZATION_LEVEL", values="-O2")
    else:
        app.set_app_config(key="USER_COMPILE_DEBUG_LEVEL", values="-g3")
        app.set_app_config(key="USER_COMPILE_OPTIMIZATION_LEVEL", values="-O0")
    app.build()

vitis.dispose()
