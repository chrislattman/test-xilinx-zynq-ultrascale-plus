/*
 * a53_boot.S: minimal stand-in for the FSBL when running the A53 applications
 * in upstream QEMU (machine xlnx-zcu102). Runs on A53#0 at EL3.
 *
 * 1. Enables UART1, the console used by every BSP (left disabled at reset;
 *    on hardware the FSBL/psu_init does this).
 * 2. Points A53#1/#2's reset vectors (APU RVBARADDRn) at their applications
 *    and releases them from reset (CRF_APB RST_FPD_APU), as the FSBL does.
 * 3. Jumps to hello_world_a53.
 *
 * Linked at 0xFFFC0000 (start of OCM, where the FSBL runs on hardware).
 * A53_0_ENTRY, A53_1_ENTRY and A53_2_ENTRY are passed in by the Makefile.
 */
    .text
    .global _start
_start:
    // UART1: 8N1, then enable TX/RX (same as XUartPs_EnableUart)
    ldr     x1, =0xFF010000
    mov     w0, #0x20                   // MR: no parity, 8 data bits, 1 stop bit
    str     w0, [x1, #0x04]
    mov     w0, #0x114                  // CR: TXEN | RXEN | STPBRK
    str     w0, [x1, #0x00]

    // Reset vectors for A53#1 and A53#2 (RVBARADDRnL/H)
    ldr     x1, =0xFD5C0000             // APU base
    ldr     x0, =A53_1_ENTRY
    str     w0, [x1, #0x48]
    lsr     x0, x0, #32
    str     w0, [x1, #0x4C]
    ldr     x0, =A53_2_ENTRY
    str     w0, [x1, #0x50]
    lsr     x0, x0, #32
    str     w0, [x1, #0x54]

    // Release A53#1 and A53#2 from reset (ACPU1_RESET, ACPU2_RESET)
    ldr     x1, =0xFD1A0104             // CRF_APB RST_FPD_APU
    ldr     w0, [x1]
    bic     w0, w0, #0x6
    str     w0, [x1]

    ldr     x0, =A53_0_ENTRY
    br      x0
