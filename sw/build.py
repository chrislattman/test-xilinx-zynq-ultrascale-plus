import argparse
import vitis
from vitis.component import HostComponent
from vitis.platform_component import Platform

APP_NAMES = ["hello_world_a53", "hello_world_a53_1", "hello_world_a53_2", "hello_world_r5"]

release_mode = False
parser = argparse.ArgumentParser()
parser.add_argument("--release", action="store_true")
clean_group = parser.add_mutually_exclusive_group()
clean_group.add_argument("--clean", action="store_true",
                         help="clean the application components only")
clean_group.add_argument("--distclean", action="store_true",
                         help="clean the application components and the platform (BSPs)")
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
assert isinstance(platform, Platform)

if args.clean or args.distclean:
    for app_name in APP_NAMES:
        app = client.get_component(app_name)
        assert isinstance(app, HostComponent)
        app.clean()
    if args.distclean:
        platform.clean()
    vitis.dispose()
    raise SystemExit(0)

# platform.update_hw(hw_design="../fpga/design_1_wrapper.xsa")  # re-read the XSA if desired
for domain_name, flags in domains.items():
    domain_object = platform.get_domain(domain_name)
    domain_object.set_config(option="proc", param="proc_extra_compiler_flags", value=flags)
# The board's console is UART1. bsp.yaml records psu_uart_1, but a freshly cleaned BSP
# regenerates bspconfig.h from the default (psu_uart_0), so set it explicitly for every
# domain (including the FSBL and PMUFW) or the console moves to UART0 after --distclean.
for domain in platform.list_domains():
    domain_object = platform.get_domain(domain["domain_name"])
    for param in ["standalone_stdin", "standalone_stdout"]:
        domain_object.set_config(option="os", param=param, value="psu_uart_1")
platform.build()

for app_name in APP_NAMES:
    app = client.get_component(app_name)
    assert isinstance(app, HostComponent)
    if release_mode:
        app.set_app_config(key="USER_COMPILE_DEBUG_LEVEL", values="")
        app.set_app_config(key="USER_COMPILE_OPTIMIZATION_LEVEL", values="-O2")
    else:
        app.set_app_config(key="USER_COMPILE_DEBUG_LEVEL", values="-g3")
        app.set_app_config(key="USER_COMPILE_OPTIMIZATION_LEVEL", values="-O0")
    app.build()

vitis.dispose()
