GRUB_SRC := grub-2.12
LINUX_REL := 6.13.1
LINUX_SRC := linux-$(LINUX_REL)
BUSYBOX_SRC := busybox-1.37.0
BZIMAGE := $(LINUX_SRC)/arch/x86_64/boot/bzImage

all: hdimage.img

$(GRUB_SRC):
	wget https://ftp.gnu.org/gnu/grub/$(GRUB_SRC).tar.xz
	tar xf $(GRUB_SRC).tar.xz
	rm $(GRUB_SRC).tar.xz

$(GRUB_SRC)/grub-install: $(GRUB_SRC)
	cd $(GRUB_SRC) && \
	echo depends bli part_gpt > grub-core/extra_deps.lst && \
	./configure --target=x86_64 --with-platform=efi && \
	$(MAKE)


$(LINUX_SRC):
	wget https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_SRC).tar.xz
	tar xf $(LINUX_SRC).tar.xz
	rm $(LINUX_SRC).tar.xz

$(LINUX_SRC)/.config: linux_config
	cp linux_config $(LINUX_SRC)/.config

$(BZIMAGE): $(LINUX_SRC)/.config
	$(MAKE) -C $(LINUX_SRC)

espmnt:
	mkdir espmnt

rootmnt:
	mkdir rootmnt

hdimage.img: espmnt rootmnt $(GRUB_SRC)/grub-install
	# create image, gpt label and partitions
	dd if=/dev/zero of=hdimage.img bs=1M count=512
	cat hdimage.sfdisk | sfdisk hdimage.img
	kpartx -av hdimage.img
	# format filesystems
	mkfs.fat -F32 /dev/mapper/loop0p1
	mkfs.ext4 /dev/mapper/loop0p2
	# mount them
	mount /dev/mapper/loop0p1 espmnt
	mount /dev/mapper/loop0p2 rootmnt
	# install bootloader and kernel
	cp -r esp/* espmnt/
	
	cp $(BZIMAGE) espmnt/vmlinuz
	
	mkdir -p rootmnt/boot/efi/
	# unmount
	umount espmnt
	umount rootmnt
	kpartx -d hdimage.img

.PHONY: clean test
cleanimg:
	rm -r hdimage.img rootmnt

test: hdimage.img
	qemu-system-x86_64 -m 512m -bios /usr/share/ovmf/OVMF.fd -hda hdimage.img


#$(BUSYBOX_SRC).tar.bz2:
#	wget "https://www.busybox.net/downloads/busybox-1.37.0.tar.bz2"
	


