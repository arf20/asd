GRUB_SRC := grub-2.12
LINUX_REL := 6.13.1
LINUX_SRC := linux-$(LINUX_REL)
BUSYBOX_SRC := busybox-1.37.0
BZIMAGE := $(LINUX_SRC)/arch/x86/boot/bzImage

all: hdimage.img

$(GRUB_SRC)/README:
	wget https://ftp.gnu.org/gnu/grub/$(GRUB_SRC).tar.xz
	tar xf $(GRUB_SRC).tar.xz
	rm $(GRUB_SRC).tar.xz

$(GRUB_SRC)/grub-install: $(GRUB_SRC)/README
	cd $(GRUB_SRC) && \
	echo depends bli part_gpt > grub-core/extra_deps.lst && \
	./configure --target=x86_64 --with-platform=efi && \
	make


$(LINUX_SRC)/README:
	wget https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_SRC).tar.xz
	tar xf $(LINUX_SRC).tar.xz
	rm $(LINUX_SRC).tar.xz
	cp linux_config $(LINUX_SRC)/.config

$(BZIMAGE): $(LINUX_SRC)/.config
	cd $(LINUX_SRC) && make

espmnt:
	mkdir espmnt

rootmnt:
	mkdir rootmnt

hdimage.img: espmnt rootmnt $(GRUB_SRC)/grub-install $(BZIMAGE)
	# create image, gpt label and partitions
	dd if=/dev/zero of=hdimage.img bs=1M count=512
	cat hdimage.sfdisk | sfdisk hdimage.img
	kpartx -av hdimage.img
	# format filesystems
	mkfs.fat -F32 /dev/mapper/loop0p2
	mkfs.ext4 /dev/mapper/loop0p3
	# correct loops and mount them
	losetup /dev/loop1 /dev/mapper/loop0p2
	losetup /dev/loop2 /dev/mapper/loop0p3
	mount /dev/loop1 espmnt
	mount /dev/loop2 rootmnt
	# copy base files
	cp -r esp/* espmnt/
	cp -r root/* rootmnt/
	# install kernel to ESP
	cp $(BZIMAGE) espmnt/vmlinuz
	# install UEFI bootloader
	
	# install BIOS bootloader
	cp $(BZIMAGE) rootmnt/boot/vmlinuz
	./$(GRUB_SRC)/grub-install --target=i386-pc --directory=$(GRUB_SRC)/grub-core --root-directory=$(shell pwd)/rootmnt/ --modules="normal part_msdos part_gpt multiboot" --no-floppy /dev/loop0
	
	# unmount
	umount espmnt
	umount rootmnt
	losetup -d /dev/loop1
	losetup -d /dev/loop2
	kpartx -d hdimage.img

.PHONY: clean test
cleanimg:
	rm -r hdimage.img

uefitest: hdimage.img
	qemu-system-x86_64 -m 512m -bios /usr/share/ovmf/OVMF.fd -hda hdimage.img

biostest: hdimage.img
	qemu-system-x86_64 -m 512m -hda hdimage.img


#$(BUSYBOX_SRC).tar.bz2:
#	wget "https://www.busybox.net/downloads/busybox-1.37.0.tar.bz2"
	


