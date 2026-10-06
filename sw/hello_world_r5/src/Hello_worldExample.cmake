set(IOMODULE_NUM_DRIVER_INSTANCES "")
set(UARTLITE_NUM_DRIVER_INSTANCES "")
set(UARTNS550_NUM_DRIVER_INSTANCES "")
set(UARTPS_NUM_DRIVER_INSTANCES "psu_uart_0;psu_uart_1")
set(UARTPS0_PROP_LIST "0xff000000")
list(APPEND TOTAL_UARTPS_PROP_LIST UARTPS0_PROP_LIST)
set(UARTPS1_PROP_LIST "0xff010000")
list(APPEND TOTAL_UARTPS_PROP_LIST UARTPS1_PROP_LIST)
set(UARTPSV_NUM_DRIVER_INSTANCES "")
set(psu_r5_ddr_0_memory_0 "0x100000;0x7fefffff")
set(psu_ocm_ram_0_memory_0 "0xfffc0000;0x40000")
set(DDR psu_r5_ddr_0_memory_0)
set(CODE psu_r5_ddr_0_memory_0)
set(DATA psu_r5_ddr_0_memory_0)
set(TOTAL_MEM_CONTROLLERS "psu_r5_ddr_0_memory_0;psu_ocm_ram_0_memory_0")
set(MEMORY_SECTION "MEMORY
{
	psu_r5_0_atcm_MEM_0 : ORIGIN = 0x0, LENGTH = 0x10000
	psu_r5_0_btcm_MEM_0 : ORIGIN = 0x20000, LENGTH = 0x10000
	psu_r5_tcm_ram_0_MEM_0 : ORIGIN = 0x0, LENGTH = 0x40000
	psu_r5_ddr_0_memory_0 : ORIGIN = 0x100000, LENGTH = 0x7fefffff
	psu_ocm_ram_0_memory_0 : ORIGIN = 0xfffc0000, LENGTH = 0x40000
}")
set(STACK_SIZE 0x2000)
set(HEAP_SIZE 0x2000)
