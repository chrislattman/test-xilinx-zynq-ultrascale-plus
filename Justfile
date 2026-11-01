xsdb := env("XSDB", "xsdb")
find_filter := xsdb + " find_jtag_filters.tcl"

# Zynq UltraScale+ (xczu3): GDB ports 3000 (R5) / 3001 (A53)
# Zynq 7000 (xc7z020):      GDB port  3100 (A9)
# Both filters are looked up before either hw_server starts, since a cable
# claimed by a running hw_server may not be visible to the lookup.
run-both-hw-servers:
	zynqmp=$({{find_filter}} --zynqmp) && zynq=$({{find_filter}} --zynq) && \
	{ hw_server -s tcp:127.0.0.1:3121 -p 3000 -e "set jtag-port-filter $zynqmp" & \
	  hw_server -s tcp:127.0.0.1:3122 -p 3100 -e "set jtag-port-filter $zynq" & }

stop-both-hw-servers:
	pkill hw_server
