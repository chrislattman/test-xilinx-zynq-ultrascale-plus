/*
 * Real functions for BSP APIs that are function-like macros, which bindgen
 * cannot see. (static inline functions such as Xil_Out32() are handled
 * automatically by bindgen's wrap_static_fns instead.)
 *
 * Every function here is named xilrs_<Name>. The build helper strips the
 * prefix, so Rust code calls them by their original names, e.g.
 * XTtcPs_Start(), and bindgen links them to the prefixed symbol through
 * #[link_name].
 */
#ifndef XILRS_SHIM_H
#define XILRS_SHIM_H

#include "xil_types.h"
#include "xttcps.h"
#include "xwdtps.h"

/* xttcps.h */
void xilrs_XTtcPs_Start(XTtcPs *InstancePtr);
void xilrs_XTtcPs_Stop(XTtcPs *InstancePtr);
u32 xilrs_XTtcPs_IsStarted(XTtcPs *InstancePtr);
XInterval xilrs_XTtcPs_GetCounterValue(XTtcPs *InstancePtr);
void xilrs_XTtcPs_SetInterval(XTtcPs *InstancePtr, XInterval Value);
XInterval xilrs_XTtcPs_GetInterval(XTtcPs *InstancePtr);
void xilrs_XTtcPs_ResetCounterValue(XTtcPs *InstancePtr);
void xilrs_XTtcPs_EnableInterrupts(XTtcPs *InstancePtr, u32 InterruptMask);
void xilrs_XTtcPs_DisableInterrupts(XTtcPs *InstancePtr, u32 InterruptMask);
u32 xilrs_XTtcPs_GetInterruptStatus(XTtcPs *InstancePtr);
void xilrs_XTtcPs_ClearInterruptStatus(XTtcPs *InstancePtr, u32 InterruptMask);

/* xwdtps.h */
void xilrs_XWdtPs_RestartWdt(XWdtPs *InstancePtr);
u32 xilrs_XWdtPs_IsWdtExpired(XWdtPs *InstancePtr);

/* xpseudo_asm_gcc.h barriers (dmb sy / dsb sy / isb sy, same as the C macros) */
void xilrs_dmb(void);
void xilrs_dsb(void);
void xilrs_isb(void);

#endif
