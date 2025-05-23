
AS=nasm
ASFLAGS=-g -O0

# From: https://github.com/8dcc/i686-cross-compiler
LD=/usr/local/cross/bin/i686-elf-ld
LDFLAGS=--fatal-warnings -nostdlib

QEMU=qemu-system-i386

# NOTE: The '-enable-kvm' and '-cpu host' options could be added, but they mess
# with GDB breakpoints, specially for bootloader debugging.
#
# See the comments in: https://stackoverflow.com/a/14269843/11715554
QEMUFLAGS=-rtc base=localtime            \
          -audiodev pa,id=audio0         \
          -machine pcspk-audiodev=audio0 \
          -monitor stdio

STAGE1_BIN=stage1.bin
STAGE1_SRC=src/stage1.asm
STAGE1_OBJ=$(patsubst src/%,obj/%.o,$(STAGE1_SRC))

STAGE2_BIN=stage2.bin
STAGE2_SRC=src/stage2.asm
STAGE2_OBJ=$(patsubst src/%,obj/%.o,$(STAGE2_SRC))

BOOT_IMG=boot.img

# ------------------------------------------------------------------------------

.PHONY: all clean qemu qemu-debug elf-bins

all: $(BOOT_IMG)

clean:
	rm -f $(STAGE1_BIN) $(STAGE1_OBJ)
	rm -f $(STAGE2_BIN) $(STAGE2_OBJ)
	rm -f $(BOOT_IMG)

qemu: $(BOOT_IMG)
	$(QEMU) $(QEMUFLAGS) -boot a -drive file=$^,format=raw,readonly=on,if=floppy

qemu-debug:
	$(MAKE) QEMUFLAGS="$(QEMUFLAGS) -s -S" qemu

# Generate ELF binaries that can't be run by the BIOS, but that can be used for
# loading debug information into GDB.
elf-bins:
	$(MAKE) LDFLAGS="$(LDFLAGS) --oformat=elf32-i386" \
		STAGE1_BIN=$(STAGE1_BIN:.bin=.elf) $(STAGE1_BIN:.bin=.elf)
	$(MAKE) LDFLAGS="$(LDFLAGS) --oformat=elf32-i386" \
		STAGE2_BIN=$(STAGE2_BIN:.bin=.elf) $(STAGE2_BIN:.bin=.elf)

# ------------------------------------------------------------------------------

# First, an empty image is created, then a base FAT12 filesystem is created.
#
# We specify many options related to floppy disks, but they don't necessarily
# have to match the values in the BPB in the Stage 1 binary, since the
# 'copy-fat12-boot.sh' script skips most of the BPB.
$(BOOT_IMG): $(STAGE1_BIN) $(STAGE2_BIN)
	dd if=/dev/zero of=$@ bs=512 count=100
	mkfs.fat -F 12 -D 0 -M 0xF0 -s 1 -S 512 -r 112 $@
	mcopy -i $@ $^ "::/"
	scripts/copy-fat12-boot.sh $(STAGE1_BIN) $(BOOT_IMG)

# The Stage 1 and Stage 2 flat binaries are linked from the ELF object files.
$(STAGE1_BIN): $(STAGE1_OBJ)
	$(LD) $(LDFLAGS) -L linker -T linker/stage1.ld -o $@ $^

$(STAGE2_BIN): $(STAGE2_OBJ)
	$(LD) $(LDFLAGS) -L linker -T linker/stage2.ld -o $@ $^

# The sources are assembled into ELF object files, that will be later linked
# into flat binaries, as specified in the linker scripts.
obj/%.asm.o: src/%.asm
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -f elf32 -i $(dir $<) -o $@ $<
