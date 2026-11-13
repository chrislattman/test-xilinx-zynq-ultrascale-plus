//! Rust version of `shared_mem/shared_mem.h`: the mailbox from A53#1, A53#2 and
//! R5#0 to A53#0, which owns UART1.
//!
//! The cores don't share peripherals, so only A53#0 prints. The other cores
//! post their messages here ([`Mailbox::post`]) and A53#0 prints them
//! ([`Mailbox::pop`]).
//!
//! The mailbox lives in its own 2 MB block of DDR (the A53 MMU's block size),
//! above every application's linker script regions:
//!
//! | Range                     | Owner                                  |
//! |---------------------------|----------------------------------------|
//! | `0x00040000 - 0x0FFFFFFF` | A53#0 (`hello_world_a53_rs/linker.ld`)   |
//! | `0x10000000 - 0x1FFFFFFF` | A53#1 (`hello_world_a53_1_rs/linker.ld`) |
//! | `0x20000000 - 0x2FFFFFFF` | A53#2 (`hello_world_a53_2_rs/linker.ld`) |
//! | `0x30000000 - 0x301FFFFF` | this mailbox                           |
//!
//! R5#0 runs from its TCM.
//!
//! The R5 isn't cache-coherent with the A53 cluster, so every core maps the
//! block as non-cacheable before using it, all with the same attributes
//! (`Xil_SetTlbAttributes(MAILBOX_BASE, NORM_NONCACHE)` on the A53s,
//! `Xil_SetMPURegion(MAILBOX_BASE, MAILBOX_SIZE, NORM_NSHARED_NCACHE | PRIV_RW_USER_RW)`
//! on the R5). That's done by the apps, since it needs each core's BSP crate.
//! With one ring per sender, each counter has a single writer, so plain loads
//! and stores with barriers are enough: no read-modify-write atomics, which
//! aren't something to rely on for uncached memory shared with the R5.
//!
//! Only fixed-width fields: the A53s are 64-bit and the R5 is 32-bit. The
//! layout matches the C header, so C and Rust cores can be mixed.
#![no_std]

use core::cell::UnsafeCell;
use core::hint::spin_loop;
use core::sync::atomic::{AtomicU32, Ordering};

pub const MAILBOX_BASE: usize = 0x3000_0000;
pub const MAILBOX_SIZE: usize = 0x20_0000;
/// Written by A53#0 once the rings are cleared ("MBOX")
pub const MAILBOX_READY: u32 = 0x4D42_4F58;

/// Ring capacity: messages queued at once per sender
pub const MSG_SLOTS: usize = 8;
/// Slot size: messages are truncated to `MSG_LEN - 1` bytes (plus a NUL, like
/// the C version)
pub const MSG_LEN: usize = 64;

/// Who posted a message (one ring each)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(usize)]
pub enum Sender {
    A53_1 = 0,
    A53_2 = 1,
    R5_0 = 2,
}

impl Sender {
    pub const ALL: [Sender; 3] = [Sender::A53_1, Sender::A53_2, Sender::R5_0];
}

/// Single-producer (the sender), single-consumer (A53#0) ring of messages.
/// Both counters only increase (wrapping); `head - tail` messages are queued.
#[repr(C)]
struct Ring {
    /// Written by the sender: messages posted
    head: AtomicU32,
    /// Written by A53#0: messages printed
    tail: AtomicU32,
    msgs: UnsafeCell<[[u8; MSG_LEN]; MSG_SLOTS]>,
}

/// The struct at [`MAILBOX_BASE`], same layout as `mailbox_t` in `shared_mem.h`
#[repr(C)]
pub struct Mailbox {
    /// [`MAILBOX_READY`] once A53#0 has cleared the rings
    ready: AtomicU32,
    _reserved: u32,
    rings: [Ring; 3],
}

const _: () = assert!(size_of::<Mailbox>() == 8 + 3 * (8 + MSG_SLOTS * MSG_LEN));

// SAFETY: the atomics are Sync; the message slots are only accessed through
// post()/pop(), whose callers guarantee one producer and one consumer per ring
unsafe impl Sync for Mailbox {}

/// The mailbox. It starts out holding whatever DDR contained at power-up,
/// until A53#0 calls [`Mailbox::init`].
///
/// # Safety
/// The caller must have mapped the mailbox block non-cacheable on this core.
pub unsafe fn mailbox() -> &'static Mailbox {
    // SAFETY: nothing else is linked into the mailbox block, every field is an
    // atomic or an UnsafeCell (interior mutability), and any bit pattern is
    // valid for them
    unsafe { &*(MAILBOX_BASE as *const Mailbox) }
}

impl Mailbox {
    /// A53#0 only: clears the rings (DDR holds random values at power-up),
    /// then lets the senders start.
    pub fn init(&self) {
        for ring in &self.rings {
            ring.head.store(0, Ordering::Relaxed);
            ring.tail.store(0, Ordering::Relaxed);
        }
        // Release: the cleared counters are visible before the flag
        self.ready.store(MAILBOX_READY, Ordering::Release);
    }

    /// Senders: waits until A53#0 has cleared the rings.
    pub fn wait_ready(&self) {
        while self.ready.load(Ordering::Acquire) != MAILBOX_READY {
            spin_loop();
        }
    }

    /// Queues a message for A53#0 to print, truncated to `MSG_LEN - 1` bytes.
    /// Waits while the ring is full.
    ///
    /// # Safety
    /// Only the core that `sender` names may post to its ring, and only after
    /// [`Mailbox::wait_ready`].
    pub unsafe fn post(&self, sender: Sender, msg: &[u8]) {
        let ring = &self.rings[sender as usize];
        let head = ring.head.load(Ordering::Relaxed);
        // Acquire: A53#0 has finished reading the slot before it's overwritten
        while head.wrapping_sub(ring.tail.load(Ordering::Acquire)) >= MSG_SLOTS as u32 {
            spin_loop();
        }
        let len = msg.len().min(MSG_LEN - 1);
        // SAFETY: A53#0 doesn't read this slot again until head moves past it
        let slot = unsafe { &mut (*ring.msgs.get())[head as usize % MSG_SLOTS] };
        slot[..len].copy_from_slice(&msg[..len]);
        slot[len] = 0;
        // Release: the message is written before A53#0 can see the new head
        ring.head.store(head.wrapping_add(1), Ordering::Release);
    }

    /// Copies the oldest message from `sender`'s ring into `out` and returns
    /// its length, or returns `None` if that ring is empty.
    ///
    /// # Safety
    /// Only A53#0 may pop.
    pub unsafe fn pop(&self, sender: Sender, out: &mut [u8; MSG_LEN]) -> Option<usize> {
        let ring = &self.rings[sender as usize];
        let tail = ring.tail.load(Ordering::Relaxed);
        if ring.head.load(Ordering::Acquire) == tail {
            return None;
        }
        // SAFETY: the sender doesn't write this slot again until tail moves past it
        *out = unsafe { (*ring.msgs.get())[tail as usize % MSG_SLOTS] };
        // Release: done reading the slot before the sender can reuse it
        ring.tail.store(tail.wrapping_add(1), Ordering::Release);
        Some(out.iter().position(|&b| b == 0).unwrap_or(MSG_LEN))
    }
}
