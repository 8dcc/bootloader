; Copyright 2025 8dcc. All Rights Reserved.
;
; This program is part of naos.
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

%ifndef GST_ASM_
%define GST_ASM_

; ------------------------------------------------------------------------------

; Present bit of 'gdt_entry_t.flags'.
%assign GDT_FLAG_INVALID (0 << 7)
%assign GDT_FLAG_PRESENT (1 << 7)

; Descriptor Privilege Level (DPL) bits of 'gdt_entry_t.flags'. A value of 3
; (both set) or 0 (both clear) indicates the ring.
%assign GDT_FLAG_DPL_RING0 ((0 << 6) | (0 << 5))
%assign GDT_FLAG_DPL_RING3 ((1 << 6) | (1 << 5))

; Descriptor type bit of 'gdt_entry_t.flags'. Determines if the entry is a
; system descriptor (e.g. a Task State Segment), or a code/data one.
%assign GDT_FLAG_SYSTEM (0 << 4)
%assign GDT_FLAG_NOTSYS (1 << 4)

; Executable bit of 'gdt_entry_t.flags'. Determines whether the segment is
; executable (code) or not (data).
%assign GDT_FLAG_DATA (0 << 3)
%assign GDT_FLAG_EXEC (1 << 3)

; For data segments: Direction bit of 'gdt_entry_t.flags'. If clear, the segment
; grows up (offset < limit); if set, the segment grows down (limit < offset).
;
; For code segments: Conforming bit of 'gdt_entry_t.flags'. If set, the code in
; this segment can only be executed from its ring (as specified in the DPL bits
; 5 and 6); if clear, it can be executed from an equal or lower privilege level
; (see Intel SDM, Vol. 3, Section 3.4.5.1).
%assign GDT_FLAG_DIR_UP    (0 << 2)
%assign GDT_FLAG_DIR_DOWN  (1 << 2)
%assign GDT_FLAG_NOCONFORM (0 << 2)
%assign GDT_FLAG_CONFORM   (1 << 2)

; For code segments: Readable bit of 'gdt_entry_t.flags'. If clear, read access
; is not allowed. Write access is never allowed for code segments.
;
; For data segments: Writable bit of 'gdt_entry_t.flags'. If clear, write access
; is not allowed. Read access is always allowed for data segments.
%assign GDT_FLAG_CODE_EXECONLY  (0 << 1)
%assign GDT_FLAG_CODE_READABLE  (1 << 1)
%assign GDT_FLAG_DATA_READONLY  (0 << 1)
%assign GDT_FLAG_DATA_WRITEABLE (1 << 1)

; Accessed bit of 'gdt_entry_t.flags'. The CPU will set this bit to 1 unless it
; was set in advance. Usually best to set in advance. See Intel SDM, Vol. 3,
; Section 3.4.5.1.
%assign GDT_FLAG_NOTACCESSED (1 << 0)
%assign GDT_FLAG_ACCESSED    (1 << 1)

; ------------------------------------------------------------------------------

; Granularity bit of 'gdt_entry_t.limit1'. This flag determines how the segment
; limit is interpreted: when clear, it's assumed to be in bytes; when set, it's
; assumed to be in 4-KiB blocks.
%assign GDT_GRANULARITY_BYTES (0 << 7)
%assign GDT_GRANULARITY_4KB   (1 << 7)

; Default operation size bit of 'gdt_entry_t.limit1'. Changes depending on the
; segment type; should always be set to 1 for 32-bit code and data segments, and
; to 0 for 16-bit code and data segments.
%assign GDT_OPSIZE_16 (0 << 6)
%assign GDT_OPSIZE_32 (1 << 6)

; 64-bit code segment flag of 'gdt_entry_t.limit1'. If set, indicates that the
; instructions in this code segment are executed in 64-bit mode (long mode).
%assign GDT_64BIT_DISABLED (0 << 5)
%assign GDT_64BIT_ENABLED  (1 << 5)

; ------------------------------------------------------------------------------

; Structure representing a single entry in the Global Descriptor Table (GDT).
;
; Keep in mind that the first members on the structure represent logically lower
; bits (e.g. when represented in the Intel SDM tables), since the x86
; architecture is little-endian.
;
; See also Intel SDM, Vol. 3, Figure 3-8.
struc gdt_entry_t
    .limit0:    resw 1      ; First 16 bits of limit
    .base0:     resw 1      ; First 16 bits of base
    .base1:     resb 1      ; Mid 8 bits of base
    .flags:     resb 1      ; Segment flags and type
    .limit1:    resb 1      ; Other flags [4..7] + last 4 bits of limit [0..3]
    .base2:     resb 1      ; Last 8 bits of base
endstruc

; ------------------------------------------------------------------------------

; Requested Privilege Level (RPL) bits of a Segment Selector.
; See Intel SDM, Vol. 3, Section 3.4.2 "Segment Selectors".
%assign GDT_SELECTOR_RPL_RING0 ((0 << 1) | (0 << 0))
%assign GDT_SELECTOR_RPL_RING3 ((1 << 1) | (1 << 0))

; Table Indicator (TI) bits of a Segment Selector.
%assign GDT_SELECTOR_TI_GDT (0 << 2)
%assign GDT_SELECTOR_TI_LDT (1 << 2)

%endif ; GDT_ASM_
