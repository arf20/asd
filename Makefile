LINUX_SRC := linux-6.13.1
BUSYBOX_SRC := busybox-1.37.0
BZIMAGE := $(LINUX_SRC)/arch/x86_64/boot/bzImage

all: hdimage.img


$(LINUX_SRC).tar.xz:
	wget https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_SRC).tar.xz
	
$(LINUX_SRC): $(LINUX_SRC).tar.xz
	tar xf $(LINUX_SRC).tar.xz

$(LINUX_SRC)/.config: linux_config
	cp linux_config $(LINUX_SRC)/.config

$(BZIMAGE): $(LINUX_SRC)/.config
	$(MAKE) -C $(LINUX_SRC)

esp.img: $(BZIMAGE)
	dd if=/dev/zero of=esp.img bs=1M count=32
	mformat -i esp.img ::
	mmd -i esp.img ::/EFI
	mmd -i esp.img ::/EFI/BOOT
	mcopy -i esp.img $(BZIMAGE) ::/EFI/BOOT/BOOTX64.EFI

rootmnt:
	mkdir rootmnt

root.img: rootmnt root/
	#???
	dd if=/dev/zero of=root.img bs=1M count=478
	mkfs.ext4 root.img

hdimage.img: esp.img root.img
	dd if=/dev/zero of=hdimage.img bs=1M count=512
	cat hdimage.sfdisk | sfdisk hdimage.img
	dd if=esp.img of=hdimage.img conv=notrunc bs=512 seek=2048 count=65536
	dd if=root.img of=hdimage.img conv=notrunc bs=512 seek=67584 count=931840


.PHONY: clean test
cleanimg:
	rm -r esp.img root.img hdimage.img rootmnt

test: hdimage.img
	qemu-system-x86_64 -bios /usr/share/ovmf/OVMF.fd -hda hdimage.img


#$(BUSYBOX_SRC).tar.bz2:
#	wget "https://www.busybox.net/downloads/busybox-1.37.0.tar.bz2"
	


