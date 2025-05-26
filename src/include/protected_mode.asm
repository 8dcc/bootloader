; Copyright 2025 8dcc. All Rights Reserved.
;
; This file is part of 8dcc's bootloader.
;
; This program is free software: you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation, either version 3 of the License, or (at your option) any later
; version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
; details.
;
; You should have received a copy of the GNU General Public License along with
; this program.  If not, see <https://www.gnu.org/licenses/>.


%ifndef PROTECTED_MODE_ASM_
%define PROTECTED_MODE_ASM_ 1

; See Intel SDM, Vol. 3, Section 2.5 "Control Registers".
%assign CR0_PE (1 << 0)  ; Protection Enable
%assign CR0_MP (1 << 1)  ; Monitor Coprocessor
%assign CR0_EM (1 << 2)  ; Emulation
%assign CR0_TS (1 << 3)  ; Task Switched
%assign CR0_ET (1 << 4)  ; Extension Type
%assign CR0_NE (1 << 5)  ; Numeric Error
%assign CR0_WP (1 << 16) ; Write Protect
%assign CR0_AM (1 << 18) ; Alignment Mask
%assign CR0_NW (1 << 29) ; Not Write-through
%assign CR0_CD (1 << 30) ; Cache Disable
%assign CR0_PG (1 << 31) ; Paging Enable

%assign CR3_PCD (1 << 3) ; Page-level Cache Disable
%assign CR3_PWT (1 << 4) ; Page-level Write-Through

%assign CR4_VME        (1 << 0)  ; Virtual-8086 Mode Extensions
%assign CR4_PVI        (1 << 1)  ; Protected-Mode Virtual Interrupts
%assign CR4_TSD        (1 << 2)  ; Time Stamp Disable
%assign CR4_DE         (1 << 3)  ; Debugging Extensions
%assign CR4_PSE        (1 << 4)  ; Page Size Extensions
%assign CR4_PAE        (1 << 5)  ; Physical Address Extension
%assign CR4_MCE        (1 << 6)  ; Machine Check Enable
%assign CR4_PGE        (1 << 7)  ; Page Global Enable
%assign CR4_PCE        (1 << 8)  ; Performance Monitoring Counter Enable
%assign CR4_OSFXSR     (1 << 9)  ; Operating System FXSAVE/FXRSTOR Support
%assign CR4_OSXMMEXCPT (1 << 10) ; Op. Sys. Unmasked SIMD FP Exception Support
%assign CR4_UMIP       (1 << 11) ; User-Mode Instruction Prevention
%assign CR4_LA57       (1 << 12) ; 57-bit Linear Addresses
%assign CR4_VMXE       (1 << 13) ; VMX-Enable Bit
%assign CR4_SMXE       (1 << 14) ; SMX-Enable Bit
%assign CR4_FSGSBASE   (1 << 16) ; FSGSBASE Enable
%assign CR4_PCIDE      (1 << 17) ; PCID Enable
%assign CR4_OSXSAVE    (1 << 18) ; Operating System XSAVE Enable
%assign CR4_KL         (1 << 23) ; Key Locker Enable
%assign CR4_CET        (1 << 22) ; Control-flow Enforcement Technology
%assign CR4_PKE        (1 << 22) ; Protection Key Enable
%assign CR4_SMAP       (1 << 20) ; Supervisor Mode Access Prevention
%assign CR4_SMEP       (1 << 21) ; Supervisor Mode Execution Prevention

%endif ; PROTECTED_MODE_ASM_
