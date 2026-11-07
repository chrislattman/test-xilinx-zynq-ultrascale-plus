/* See xilrs_shim.h */
#include "xilrs_shim.h"
#include "xpseudo_asm.h"

void xilrs_XTtcPs_Start(XTtcPs *InstancePtr) { XTtcPs_Start(InstancePtr); }
void xilrs_XTtcPs_Stop(XTtcPs *InstancePtr) { XTtcPs_Stop(InstancePtr); }
u32 xilrs_XTtcPs_IsStarted(XTtcPs *InstancePtr) { return XTtcPs_IsStarted(InstancePtr); }
XInterval xilrs_XTtcPs_GetCounterValue(XTtcPs *InstancePtr) { return XTtcPs_GetCounterValue(InstancePtr); }
void xilrs_XTtcPs_SetInterval(XTtcPs *InstancePtr, XInterval Value) { XTtcPs_SetInterval(InstancePtr, Value); }
XInterval xilrs_XTtcPs_GetInterval(XTtcPs *InstancePtr) { return XTtcPs_GetInterval(InstancePtr); }
void xilrs_XTtcPs_ResetCounterValue(XTtcPs *InstancePtr) { XTtcPs_ResetCounterValue(InstancePtr); }
void xilrs_XTtcPs_EnableInterrupts(XTtcPs *InstancePtr, u32 InterruptMask) { XTtcPs_EnableInterrupts(InstancePtr, InterruptMask); }
void xilrs_XTtcPs_DisableInterrupts(XTtcPs *InstancePtr, u32 InterruptMask) { XTtcPs_DisableInterrupts(InstancePtr, InterruptMask); }
u32 xilrs_XTtcPs_GetInterruptStatus(XTtcPs *InstancePtr) { return XTtcPs_GetInterruptStatus(InstancePtr); }
/* Expands to two statements (the ISR is clear-on-read), so it can't be used as an expression */
void xilrs_XTtcPs_ClearInterruptStatus(XTtcPs *InstancePtr, u32 InterruptMask) { XTtcPs_ClearInterruptStatus(InstancePtr, InterruptMask); }

void xilrs_XWdtPs_RestartWdt(XWdtPs *InstancePtr) { XWdtPs_RestartWdt(InstancePtr); }
u32 xilrs_XWdtPs_IsWdtExpired(XWdtPs *InstancePtr) { return XWdtPs_IsWdtExpired(InstancePtr); }

void xilrs_dmb(void) { dmb(); }
void xilrs_dsb(void) { dsb(); }
void xilrs_isb(void) { isb(); }
