/*
 * shared_mem.h: mailbox from A53#1, A53#2 and R5#0 to A53#0, which owns UART1
 *
 * The cores don't share peripherals, so only A53#0 prints. The other cores post
 * their messages here and A53#0 prints them.
 *
 * The mailbox lives in its own 2 MB block of DDR (the A53 MMU's block size),
 * above every application's linker script regions:
 *   0x00040000 - 0x0FFFFFFF  A53#0 (hello_world_a53 lscript.ld)
 *   0x10000000 - 0x1FFFFFFF  A53#1 (hello_world_a53_1 lscript.ld)
 *   0x20000000 - 0x2FFFFFFF  A53#2 (hello_world_a53_2 lscript.ld)
 *   0x30000000 - 0x301FFFFF  this mailbox
 *   (R5#0 runs from its TCM)
 *
 * The R5 isn't cache-coherent with the A53 cluster, so every core maps the
 * block as non-cacheable (mailbox_map()). They must all use the same
 * attributes. With one ring per sender, each counter has a single writer, so
 * plain loads and stores with barriers are enough (no ldrex/strex, which
 * isn't something to rely on for uncached memory shared with the R5).
 *
 * Only fixed-width fields: the A53s are 64-bit and the R5 is 32-bit.
 *
 * Each core also makes the other cores' private DDR inaccessible to itself,
 * so a stray access raises a data abort instead of corrupting another core
 * (the debugger and DMA masters bypass the MMU/MPU and are not affected):
 *   - each A53 unmaps the other A53s' regions in its MMU (unmap_blocks())
 *   - R5#0 blocks all three A53 regions in its MPU (unmap_a53_ddr())
 * The A53 regions are 2 MB block aligned. A53#0's starts at 0x0 rather than
 * 0x40000 because 0x0 - 0x3FFFF shares a block with it (that's where QEMU
 * loads hello_world_r5, see sw/README.md).
 */

#ifndef SHARED_MEM_H
#define SHARED_MEM_H

#include <stdatomic.h>
#include <stdint.h>
#include <string.h>

#include <xil_types.h>
#include <xstatus.h>
#ifdef ARMR5
#include <xil_mpu.h>
#else
#include <xil_mmu.h>
#endif

/* Private DDR regions, [BASE, END) */
#define A53_0_PRIVATE_BASE  0x00000000U
#define A53_0_PRIVATE_END   0x10000000U
#define A53_1_PRIVATE_BASE  0x10000000U
#define A53_1_PRIVATE_END   0x20000000U
#define A53_2_PRIVATE_BASE  0x20000000U
#define A53_2_PRIVATE_END   0x30000000U

/* R5#0's TCM, at 0x0 in its own address map (ATCM + BTCM, split or lockstep) */
#define R5_TCM_BASE         0x00000000U
#define R5_TCM_SIZE         0x40000U

#define MAILBOX_BASE        0x30000000U
#define MAILBOX_SIZE        0x200000U
/* Written by A53#0 once the rings are cleared ("MBOX") */
#define MAILBOX_READY       0x4D424F58U

#define MSG_SLOTS           8U
#define MSG_LEN             64U

/* Sender (ring) indices */
#define MSG_FROM_A53_1      0U
#define MSG_FROM_A53_2      1U
#define MSG_FROM_R5_0       2U
#define MSG_SENDERS         3U

/* Single-producer (the sender), single-consumer (A53#0) ring of messages.
 * Both counters only increase (wrapping); head - tail = messages queued. */
typedef struct {
    atomic_uint head;       /* written by the sender: messages posted */
    atomic_uint tail;       /* written by A53#0: messages printed */
    char msgs[MSG_SLOTS][MSG_LEN];
} msg_ring_t;

typedef struct {
    atomic_uint ready;      /* MAILBOX_READY once A53#0 has cleared the rings */
    uint32_t reserved;
    msg_ring_t ring[MSG_SENDERS];
} mailbox_t;

_Static_assert(sizeof(mailbox_t) == 8 + MSG_SENDERS * (8 + MSG_SLOTS * MSG_LEN), "mailbox layout");

#define MAILBOX ((mailbox_t *)(UINTPTR)MAILBOX_BASE)

/* Every core: map the mailbox block as non-cacheable before touching it */
static inline int mailbox_map(void)
{
#ifdef ARMR5
    return (int)Xil_SetMPURegion(MAILBOX_BASE, MAILBOX_SIZE, NORM_NSHARED_NCACHE | PRIV_RW_USER_RW);
#else
    Xil_SetTlbAttributes(MAILBOX_BASE, NORM_NONCACHE);
    return XST_SUCCESS;
#endif
}

#ifdef ARMR5
/*
 * R5#0 only: no access to the A53s' private DDR (0x0 - 0x2FFFFFFF).
 *
 * The BSP's MPU region 0 maps 0x0 - 0x7FFFFFFF (TCM and DDR) and Init_MPU()
 * uses regions 0-9, and mailbox_map() takes the next free one. The R5 checks
 * TCM accesses against the MPU too, and the no-access regions start at 0x0,
 * so region 15 (the highest number wins where regions overlap) first keeps
 * the TCM accessible with the BSP's attributes. It must be set before the
 * no-access regions, since this code and its stack run from TCM.
 */
static inline int unmap_a53_ddr(void)
{
    u32 status = Xil_SetMPURegionByRegNum(15U, R5_TCM_BASE, R5_TCM_SIZE,
                                          NORM_NSHARED_WB_WA | PRIV_RW_USER_RW);
    if (status != XST_SUCCESS) {
        return (int)status;
    }
    /* MPU regions are power-of-two sized and aligned: 512 MB + 256 MB */
    status = Xil_SetMPURegionByRegNum(13U, A53_0_PRIVATE_BASE, A53_2_PRIVATE_BASE - A53_0_PRIVATE_BASE,
                                      NO_ACCESS | EXECUTE_NEVER);
    if (status != XST_SUCCESS) {
        return (int)status;
    }
    return (int)Xil_SetMPURegionByRegNum(14U, A53_2_PRIVATE_BASE, A53_2_PRIVATE_END - A53_2_PRIVATE_BASE,
                                         NO_ACCESS | EXECUTE_NEVER);
}
#else
#define A53_BLOCK_SIZE      0x200000U

/*
 * A53s only: marks [base, end) as invalid (RESERVED, an invalid descriptor)
 * in this core's MMU table, one 2 MB block at a time, so any access from this
 * core raises a synchronous abort. Each A53 application has its own table.
 */
static inline void unmap_blocks(UINTPTR base, UINTPTR end)
{
    for (UINTPTR addr = base; addr < end; addr += A53_BLOCK_SIZE) {
        Xil_SetTlbAttributes(addr, RESERVED);
    }
}
#endif

/* A53#0 only: clear the rings (DDR holds random values at power-up), then
 * let the senders start */
static inline void mailbox_init(void)
{
    for (unsigned i = 0; i < MSG_SENDERS; i++) {
        atomic_store_explicit(&MAILBOX->ring[i].head, 0, memory_order_relaxed);
        atomic_store_explicit(&MAILBOX->ring[i].tail, 0, memory_order_relaxed);
    }
    /* Release: the cleared counters are visible before the flag */
    atomic_store_explicit(&MAILBOX->ready, MAILBOX_READY, memory_order_release);
}

/* Senders: wait until A53#0 has cleared the rings */
static inline void mailbox_wait_ready(void)
{
    while (atomic_load_explicit(&MAILBOX->ready, memory_order_acquire) != MAILBOX_READY)
        ;
}

/* Sender only: queue a message for A53#0 to print, truncated to MSG_LEN - 1
 * characters. Waits while the ring is full. */
static inline void msg_post(unsigned sender, const char *msg)
{
    msg_ring_t *r = &MAILBOX->ring[sender];
    unsigned head = atomic_load_explicit(&r->head, memory_order_relaxed);
    /* Acquire: A53#0 has finished reading the slot before it's overwritten */
    while (head - atomic_load_explicit(&r->tail, memory_order_acquire) >= MSG_SLOTS)
        ;
    char *slot = r->msgs[head % MSG_SLOTS];
    strncpy(slot, msg, MSG_LEN - 1);
    slot[MSG_LEN - 1] = '\0';
    /* Release: the message is written before A53#0 can see the new head */
    atomic_store_explicit(&r->head, head + 1, memory_order_release);
}

/* A53#0 only: copy the oldest message from a sender's ring into out and
 * return 1, or return 0 if that ring is empty */
static inline int msg_pop(unsigned sender, char out[MSG_LEN])
{
    msg_ring_t *r = &MAILBOX->ring[sender];
    unsigned tail = atomic_load_explicit(&r->tail, memory_order_relaxed);
    if (atomic_load_explicit(&r->head, memory_order_acquire) == tail)
        return 0;
    memcpy(out, r->msgs[tail % MSG_SLOTS], MSG_LEN);
    /* Release: done reading the slot before the sender can reuse it */
    atomic_store_explicit(&r->tail, tail + 1, memory_order_release);
    return 1;
}

#endif
