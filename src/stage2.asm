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

;------------------------------------------------------------------------------
; Includes

%include "include/boot_config.asm"
%include "include/error_codes.asm"
%include "include/bios_codes.asm"
%include "include/fat12_structures.asm"
%include "include/gdt.asm"
%include "include/protected_mode.asm"

extern bpb

;-------------------------------------------------------------------------------
; Stage 2 entry point

bits 16
section .text

global stage2_entry
stage2_entry:
    mov     si, str_stage2_loaded
    call    bios_println

    ; Try to enable the A20 line.
    call    enable_a20
    test    ax, ax
    jnz     .a20_enabled

    ; The 'enable_a20' function returned false.
    mov     si, str_a20_error
    call    bios_println
    jmp     halt

.a20_enabled:
    ; The 'enable_a20' function returned true.
    mov     si, str_a20_enabled
    call    bios_println

    ; Load the bootloader's GDT, needed before jumping into protected mode.
    lgdt    [gdt_pseudodescriptor]
    mov     si, str_gdt_loaded
    call    bios_println

    ; Set the Protection Enable bit of CR0.
    ; See Intel SDM, Vol. 3, Section 9.9.1 "Switching to Protected Mode"
    mov     eax, cr0
    or      al, CR0_PE
    mov     cr0, eax

    ; 32-bit code and data segment selectors for the bootloader.
    ;
    ; The lower 3 bits are used for the RPL and TI flags; in this case, we want
    ; to use the GDT (rather than the LDT), in Ring 0 privilege. Bits [3..15]
    ; indicate the GDT index of the segment descriptor that should be used,
    ; which should match the GDT definition below (in the '.data' section).
    ;
    ; See Intel SDM, Vol. 3, Section 3.4.2 "Segment Selectors".
    %assign CODE_SELECTOR_32BIT ((3 << 3) | GDT_SELECTOR_TI_GDT |              \
                                 GDT_SELECTOR_RPL_RING0)
    %assign DATA_SELECTOR_32BIT ((4 << 3) | GDT_SELECTOR_TI_GDT |              \
                                 GDT_SELECTOR_RPL_RING0)

    ; Perform a far jump into the next instruction. The value of the segment is
    ; the code selector that was defined above, which will be loaded into the CS
    ; register after the jump.
    jmp     CODE_SELECTOR_32BIT:.protected_mode_enabled

.protected_mode_enabled:
    bits 32

    ; Load the segment registers with the segment selectors that were defined
    ; above.
    mov     ax, CODE_SELECTOR_32BIT
    mov     cs, ax
    mov     ax, DATA_SELECTOR_32BIT
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     ss, ax

    jmp     halt

;-------------------------------------------------------------------------------
; Functions from Stage 1

bits 16

; Included from external file to avoid duplicating code in Stage 1 and Stage 2.
%include "bios_disk.asm"
%include "bios_print.asm"

;-------------------------------------------------------------------------------
; A20 line functions

; bool enable_a20(void);
;
; Try to enable the A20 line with every supported method. Returns 1 in AX if the
; A20 line was enabled, or 0 otherwise.
enable_a20:
    pushf

    ; First, check if the A20 line is already enabled by the BIOS.
    call    is_a20_enabled
    test    ax, ax
    jnz     .success

    call    enable_a20_bios
    call    is_a20_enabled
    test    ax, ax
    jnz     .success

    call    enable_a20_keyboard
    call    is_a20_enabled
    test    ax, ax
    jnz     .success

    ; TODO: Try "Fast A20" method last

    ; If all of the above methods failed, signal the caller that we couldn't
    ; enable it.
    mov     ax, 0
    jmp     .done

.success:
    mov     ax, 1

.done:
    popf
    ret

; bool is_a20_enabled(void);
;
; Returns 1 in AX if the A20 line is enabled, or 0 otherwise.
;
; This check is done by comparing the value at 0000:7DFE (which should contain
; the boot signature 0xAA55) with the value 1MiB higher, at FFFF:7E0E. If the
; two values are different it means that the A20 is enabled.
;
; TODO: Why is 0000:0500 and FFFF:0510 used below?
is_a20_enabled:
    pushf
    push    ds
    push    es
    push    si
    push    di

    mov     ax, 0x0000
    mov     ds, ax
    mov     si, 0x0500          ; DS:SI = 0000:0500

    mov     ax, 0xFFFF
    mov     es, ax
    mov     di, 0x0510          ; ES:DI = FFFF:0510

    ; Preserve values at DS:SI and ES:DI.
    mov     al, byte [ds:si]
    push    ax
    mov     al, byte [es:di]
    push    ax

    ; Clear address A and set address B. If address A also changed, they are
    ; equivalent, so we can assume that the A20 line is disabled.
    mov     byte [ds:si], 0x00
    mov     byte [es:di], 0xFF
    cmp     byte [ds:si], 0xFF

    ; Right after using CMP to set ZF, restore the values that were overwritten
    ; in DS:SI and ES:DI.
    pop     ax
    mov     byte [ds:si], al
    pop     ax
    mov     byte [es:di], al

    ; Now we can return based on the ZF flag. If the previous values we compared
    ; were equal, the A20 line is not enabled.
    mov     ax, 0
    je      .done
    mov     ax, 1

.done:
    pop     di
    pop     si
    pop     es
    pop     ds
    popf
    ret

; bool enable_a20_bios(void);
;
; Try to enable the A20 line with the BIOS interrupt 0x15.
enable_a20_bios:
    mov     ax, BIOS_A20_SUPPORT
    int     BIOS_INT_MISC
    jb      .error              ; Not supported
    test    ah, ah
    jnz     .error              ; Not supported

    mov     ax, BIOS_A20_STATUS
    int     BIOS_INT_MISC
    jb      .error              ; Couldn't get status
    test    ah, ah
    jnz     .error              ; Couldn't get status

    cmp     al, 1
    je      .done               ; Success, already enabled

    mov     ax, BIOS_A20_ENABLE
    int     BIOS_INT_MISC
    jb      .error              ; Couldn't enable A20 line
    test    ah, ah
    jnz     .error              ; Couldn't enable A20 line

    mov     ax, 1
    jmp     .done               ; Success, enabled by BIOS

.error:
    mov     ax, 0

.done:
    ret

; bool enable_a20_keyboard(void);
;
; Try to enable the A20 line through the keyboard.
;
; TODO: Move these magic values to macros, explain this function better.
enable_a20_keyboard:
    cli

    call    .wait2
    mov     al, 0xAD
    out     0x64, al

    call    .wait2
    mov     al, 0xD0
    out     0x64, al

    call    .wait1
    mov     al, 0x60
    push    eax

    call    .wait2
    mov     al, 0xD1
    out     0x64, al

    call    .wait2
    pop     eax
    or      al, 2
    out     0x60, al

    call    .wait2
    mov     al, 0xAE
    out     0x64, al

    call    .wait2

    sti
    ret

.wait1:                         ; Another procedure
    in      al, 0x64
    test    al, 1
    jnz     .wait1
    ret

.wait2:                         ; Another procedure
    in      al, 0x64
    test    al, 2
    jnz     .wait1
    ret

;-------------------------------------------------------------------------------
; Read-write data

section .data

; Flags for the code descriptor of the GDT.
%assign CODE_FLAGS1 (GDT_FLAG_PRESENT | GDT_FLAG_DPL_RING0 | GDT_FLAG_NOTSYS | \
                     GDT_FLAG_EXEC | GDT_FLAG_DIR_UP |                         \
                     GDT_FLAG_CODE_READABLE | GDT_FLAG_ACCESSED)
%assign CODE_FLAGS2 (GDT_GRANULARITY_4KB | GDT_OPSIZE_16 | GDT_64BIT_DISABLED)

; Flags for the data descriptor of the GDT.
%assign DATA_FLAGS1 (GDT_FLAG_PRESENT | GDT_FLAG_DPL_RING0 | GDT_FLAG_NOTSYS | \
                     GDT_FLAG_DATA | GDT_FLAG_NOCONFORM |                      \
                     GDT_FLAG_DATA_WRITEABLE | GDT_FLAG_ACCESSED)
%assign DATA_FLAGS2 (GDT_GRANULARITY_4KB | GDT_OPSIZE_16 | GDT_64BIT_DISABLED)

gdt_start:
    ; The first segment is the "null descriptor", where the base, limit, access
    ; bytes, and flags are 0. We declare 2 double words (2 * 32 bits) to fill a
    ; single GDT entry.
    .null_descriptor:
        dd      0x00000000
        dd      0x00000000

    ; The code entry for the bootloader GDT will occupy the whole memory, that
    ; is, the Base is 0x000000 and the Limit is 0x00FFFFFF. The flags are
    ; defined by OR'ing different macros above, for readability. For more
    ; information on the layout of GDT entries, see the definition in 'gdt.asm'.
    .code_descriptor_16bit:
        istruc gdt_entry_t
            at gdt_entry_t.limit0,  dw 0xFFFF
            at gdt_entry_t.base0,   dw 0x0000
            at gdt_entry_t.base1,   db 0x00
            at gdt_entry_t.flags,   db CODE_FLAGS1
            at gdt_entry_t.limit1,  db CODE_FLAGS2 | 0b00001111
            at gdt_entry_t.base2,   db 0x00
        iend

    ; The data entry has the same Limit and Base as the code entry, it just has
    ; different flags.
    .data_descriptor_16bit:
        istruc gdt_entry_t
            at gdt_entry_t.limit0,  dw 0xFFFF
            at gdt_entry_t.base0,   dw 0x0000
            at gdt_entry_t.base1,   db 0x00
            at gdt_entry_t.flags,   db DATA_FLAGS1
            at gdt_entry_t.limit1,  db DATA_FLAGS2 | 0b00001111
            at gdt_entry_t.base2,   db 0x00
        iend

    ; There needs to be 32-bit code and data descriptors for when the bootloader
    ; switches to protected mode. Only a single bit changes from zero to one.
    .code_descriptor_32bit:
        istruc gdt_entry_t
            at gdt_entry_t.limit0,  dw 0xFFFF
            at gdt_entry_t.base0,   dw 0x0000
            at gdt_entry_t.base1,   db 0x00
            at gdt_entry_t.flags,   db CODE_FLAGS1
            at gdt_entry_t.limit1,  db CODE_FLAGS2 | GDT_OPSIZE_32 | 0b00001111
            at gdt_entry_t.base2,   db 0x00
        iend

    .data_descriptor_32bit:
        istruc gdt_entry_t
            at gdt_entry_t.limit0,  dw 0xFFFF
            at gdt_entry_t.base0,   dw 0x0000
            at gdt_entry_t.base1,   db 0x00
            at gdt_entry_t.flags,   db DATA_FLAGS1
            at gdt_entry_t.limit1,  db DATA_FLAGS2 | GDT_OPSIZE_32 | 0b00001111
            at gdt_entry_t.base2,   db 0x00
        iend
gdt_end:

; Ensure that the following GDT pseudo-descriptor is double-word aligned at
; compile-time, since that's what the 'LGDT' instruction expects. This check
; assumes that the start of the current section is also doubleword-aligned,
; which should be true according to our linker script.
%if (($-$$) % 4 != 0)
%warning "GDT pseudo-descriptor is not doubleword-aligned, expected by `LGDT'."
times (4 - (($-$$) % 4)) db 0x00
%endif

; Pseudo-descriptor for the GDT. See Intel SDM, Vol. 3, Section 2.4.1 "Global
; Descriptor Table Register" and Figure 3-11.
;
; Note that the the limit value will be internally added to the base address to
; get the address of the last valid byte, so it must be the GDT size minus
; one. See Intel SDM, Vol. 3, Section 3.5.1 "Segment Descriptor Tables".
gdt_pseudodescriptor:
    dw      gdt_end - gdt_start - 1     ; Size of the GDT, minus one (16 bits)
    dd      gdt_start                   ; Pointer to the GDT (32 bits)

;-------------------------------------------------------------------------------
; Read-only data

section .rodata

str_stage2_loaded:
    db `Initialized Stage 2 at address 0x`, %num(STAGE2_ADDR, -1, 16), `\0`

str_a20_error:   db `Fatal: Could not enable A20 line.\0`
str_a20_enabled: db `Successfuly enabled A20 line.\0`

str_gdt_loaded: db `Successfuly loaded bootloader GDT.\0`
