/*
 * r5_boot.S: minimal stand-in for the FSBL when running hello_world_r5 in
 * upstream QEMU (machine xlnx-zcu102, with R5#0 as the boot CPU).
 *
 * Enables UART1, the console used by the BSP (left disabled at reset; on
 * hardware the FSBL/psu_init does this), then jumps to hello_world_r5.
 *
 * Linked at 0xFFFC0000 (start of OCM, where the FSBL runs on hardware).
 * R5_ENTRY is passed in by the Makefile.
 */
    .syntax unified
    .arm
    .text
    .global _start
_start:
    ldr     r1, =0xFF010000             // UART1 base
    mov     r0, #0x20                   // MR: no parity, 8 data bits, 1 stop bit
    str     r0, [r1, #0x04]
    ldr     r0, =0x114                  // CR: TXEN | RXEN | STPBRK
    str     r0, [r1, #0x00]
    ldr     r0, =R5_ENTRY
    bx      r0
