//! Cortex-A53#0 application: no_std Rust port of `hello_world_a53/src/helloworld_a53_0.c`.
//!
//! Prints a greeting, then repeats it every 4 seconds. Sets up the UART (the
//! other cores rely on that) and owns it: the cores don't share peripherals, so
//! A53#1, A53#2 and R5#0 post their messages to the shared-memory mailbox, and
//! this core prints them, checking every second.
//! `init_platform()`/`cleanup_platform()` from the C version's platform.c do
//! nothing on this core, so they have no equivalent here.
#![no_std]
#![no_main]

#[cfg(not(xilrs_other_target))]
mod app {
    use core::ffi::{CStr, c_int};
    use core::hint::black_box;

    use shared_mem::{MAILBOX_BASE, MSG_LEN, MSG_SLOTS, Mailbox, Sender, mailbox};
    use xil_a53_0_sys::{NORM_NONCACHE, UINTPTR, Xil_SetTlbAttributes, print, sleep};

    /// Prints over UART1, which this core owns
    fn puts(s: &CStr) {
        unsafe { print(s.as_ptr()) }
    }

    /// Prints the messages the other cores posted. At most MSG_SLOTS per sender
    /// per call, so a sender that posts nonstop (like the R5 in QEMU, where its
    /// sleep() returns immediately) can't keep this core here.
    fn print_mailbox_messages(mailbox: &Mailbox) {
        let mut msg = [0u8; MSG_LEN];
        for sender in Sender::ALL {
            for _ in 0..MSG_SLOTS {
                // SAFETY: A53#0 is the mailbox's only consumer
                if unsafe { mailbox.pop(sender, &mut msg) }.is_none() {
                    break;
                }
                if let Ok(s) = CStr::from_bytes_until_nul(&msg) {
                    puts(s);
                }
            }
        }
    }

    /// Called by the BSP's startup code after it sets up the MMU, caches,
    /// stacks and .bss
    #[unsafe(no_mangle)]
    extern "C" fn main() -> c_int {
        let mut counter: u32 = 0;

        // Map the mailbox non-cacheable (the R5 isn't coherent with the A53s),
        // clear it, then let the other cores post
        let mailbox = unsafe {
            Xil_SetTlbAttributes(MAILBOX_BASE as UINTPTR, NORM_NONCACHE.into());
            mailbox()
        };
        mailbox.init();

        puts(c"Hello from Cortex-A53#0\n\r");
        loop {
            // sleep(4), checking the mailbox every second
            for _ in 0..4 {
                unsafe { sleep(1) };
                print_mailbox_messages(mailbox);
            }
            puts(c"Hello from Cortex-A53#0\n\r");
            counter = counter.wrapping_add(1);
            // Keep the counter alive so it can be watched in the debugger
            black_box(counter);
        }
    }

    #[panic_handler]
    fn panic(_info: &core::panic::PanicInfo) -> ! {
        puts(c"Cortex-A53#0 panicked\r\n");
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
