/******************************************************************************
* Copyright (C) 2023 Advanced Micro Devices, Inc. All Rights Reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/
/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <sleep.h>
#include <stdio.h>
#include "platform.h"
#include "shared_mem.h"
#include "xil_printf.h"


int main()
{
    int counter = 0;
    init_platform();

    // Fault on any access from this core to A53#0's and A53#1's private DDR
    // (see shared_mem.h for the memory map)
    unmap_blocks(A53_0_PRIVATE_BASE, A53_1_PRIVATE_END);

    // A53#0 owns UART1, so messages go through the mailbox for A53#0 to print.
    // Map it non-cacheable, then wait for A53#0 to clear it
    if (mailbox_map() != XST_SUCCESS) {
        return XST_FAILURE;
    }
    mailbox_wait_ready();

    sleep(2);
    msg_post(MSG_FROM_A53_2, "Hello from Cortex-A53#2\n\r");
    while (1) {
        sleep(4);
        msg_post(MSG_FROM_A53_2, "Hello from Cortex-A53#2\n\r");
        ++counter;
    }

    cleanup_platform();
    return 0;
}
