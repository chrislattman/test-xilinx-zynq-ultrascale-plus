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

// A53#0 owns UART1, so it also prints the messages the other cores post to the
// mailbox. At most MSG_SLOTS per sender per call, so a sender that posts nonstop
// (like the R5 in QEMU, where its sleep() returns immediately) can't keep it here.
static void print_mailbox_messages()
{
    char msg[MSG_LEN];
    for (unsigned sender = 0; sender < MSG_SENDERS; sender++) {
        for (unsigned i = 0; i < MSG_SLOTS && msg_pop(sender, msg); i++) {
            print(msg);
        }
    }
}

int main()
{
    int counter = 0;
    init_platform();

    // Fault on any access from this core to A53#1's and A53#2's private DDR
    // (see shared_mem.h for the memory map)
    unmap_blocks(A53_1_PRIVATE_BASE, A53_2_PRIVATE_END);

    // Map the mailbox non-cacheable, clear it, then let the other cores post
    if (mailbox_map() != XST_SUCCESS) {
        return XST_FAILURE;
    }
    mailbox_init();

    print("Hello from Cortex-A53#0\n\r");
    while (1) {
        // sleep(4), checking the mailbox every second
        for (int i = 0; i < 4; i++) {
            sleep(1);
            print_mailbox_messages();
        }
        print("Hello from Cortex-A53#0\n\r");
        ++counter;
    }

    cleanup_platform();
    return 0;
}
