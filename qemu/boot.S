/*
 * boot.S: minimal stand-in for the FSBL when running all four applications in
 * upstream QEMU (machine xlnx-zcu102). Runs on R5#0, the only CPU running at
 * reset (QEMU has no CRL model, so the R5 can't be released any other way).
 *
 * 1. Enables UART1, the console used by every BSP (left disabled at reset;
 *    on hardware the FSBL/psu_init does this).
 * 2. Points A53#0-#2's reset vectors (APU RVBARADDRn) at their applications
 *    and releases them from reset (CRF_APB RST_FPD_APU), as the FSBL does.
 *    They start at EL3 in AArch64.
 * 3. Jumps to hello_world_r5.
 *
 * Linked at 0xFFFC0000 (start of OCM, where the FSBL runs on hardware).
 * A53_0_ENTRY, A53_1_ENTRY, A53_2_ENTRY and R5_ENTRY are passed in by the
 * Makefile. The A53 entry points are below 4 GB, so the RVBARADDRnH (upper
 * 32 bits) registers are left at their reset value of 0.
 */
    .syntax unified
    .arm
    .text
    .global _start
_start:
    // UART1: 8N1, then enable TX/RX (same as XUartPs_EnableUart)
    ldr     r1, =0xFF010000             // UART1 base
    mov     r0, #0x20                   // MR: no parity, 8 data bits, 1 stop bit
    str     r0, [r1, #0x04]
    ldr     r0, =0x114                  // CR: TXEN | RXEN | STPBRK
    str     r0, [r1, #0x00]

    // Reset vectors for A53#0-#2 (RVBARADDRnL)
    ldr     r1, =0xFD5C0000             // APU base
    ldr     r0, =A53_0_ENTRY
    str     r0, [r1, #0x40]
    ldr     r0, =A53_1_ENTRY
    str     r0, [r1, #0x48]
    ldr     r0, =A53_2_ENTRY
    str     r0, [r1, #0x50]

    // Release A53#0-#2 from reset (ACPU0_RESET, ACPU1_RESET, ACPU2_RESET)
    ldr     r1, =0xFD1A0104             // CRF_APB RST_FPD_APU
    ldr     r0, [r1]
    bic     r0, r0, #0x7
    str     r0, [r1]

    ldr     r0, =R5_ENTRY
    bx      r0
