//! Cortex-A53#1 application: no_std Rust port of `hello_world_a53_1/src/helloworld_a53_1.c`.
//!
//! Sends a greeting after 1 s, then every 4 seconds. The cores don't share
//! peripherals: A53#0 owns UART1, so this core never prints. Its messages go
//! through the shared-memory mailbox, and A53#0 prints them.
//! `init_platform()`/`cleanup_platform()` from the C version's platform.c do
//! nothing on this core, so they have no equivalent here.
#![no_std]
#![no_main]

#[cfg(not(xilrs_other_target))]
mod app {
    use core::ffi::c_int;
    use core::hint::black_box;
    use core::sync::atomic::{AtomicBool, Ordering};

    use shared_mem::{MAILBOX_BASE, Sender, mailbox};
    use xil_a53_amp_sys::{NORM_NONCACHE, UINTPTR, Xil_SetTlbAttributes, sleep};

    /// Set once the mailbox is mapped and A53#0 has cleared it
    static MAILBOX_UP: AtomicBool = AtomicBool::new(false);

    /// Sends a message to A53#0, which prints it
    fn post(msg: &str) {
        // SAFETY: this core is the only sender on its ring, and it only posts
        // after mapping the mailbox and waiting for A53#0 (MAILBOX_UP)
        unsafe { mailbox().post(Sender::A53_1, msg.as_bytes()) }
    }

    /// Called by the BSP's startup code after it sets up the MMU, caches,
    /// stacks and .bss
    #[unsafe(no_mangle)]
    extern "C" fn main() -> c_int {
        let mut counter: u32 = 0;

        // Map the mailbox non-cacheable (the R5 isn't coherent with the A53s, and
        // every core must use the same attributes)
        let mailbox = unsafe {
            Xil_SetTlbAttributes(MAILBOX_BASE as UINTPTR, NORM_NONCACHE.into());
            mailbox()
        };
        mailbox.wait_ready();
        MAILBOX_UP.store(true, Ordering::Relaxed);

        // Staggered start so the cores' first messages arrive in order
        unsafe { sleep(1) };
        post("Hello from Cortex-A53#1\n\r");
        loop {
            unsafe { sleep(4) };
            post("Hello from Cortex-A53#1\n\r");
            counter = counter.wrapping_add(1);
            // Keep the counter alive so it can be watched in the debugger
            black_box(counter);
        }
    }

    #[panic_handler]
    fn panic(_info: &core::panic::PanicInfo) -> ! {
        // Never print directly: UART1 belongs to A53#0
        if MAILBOX_UP.load(Ordering::Relaxed) {
            post("Cortex-A53#1 panicked\r\n");
        }
        loop {}
    }
}

/// Built for the other core's target (see build.rs): there's nothing to run, but
/// a no_std binary still needs a panic handler to compile
#[cfg(xilrs_other_target)]
#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}
