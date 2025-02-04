GRUB_SRC := grub-2.12
LINUX_REL := 6.13.1
LINUX_SRC := linux-$(LINUX_REL)
BUSYBOX_REL := 1.36.1
BUSYBOX_SRC := busybox

BZIMAGE := $(LINUX_SRC)/arch/x86/boot/bzImage

all: hdimage.img

$(GRUB_SRC)-efi/README $(GRUB_SRC)-bios/README:
	wget https://ftp.gnu.org/gnu/grub/$(GRUB_SRC).tar.xz
	tar xf $(GRUB_SRC).tar.xz
	mv $(GRUB_SRC) $(GRUB_SRC)-efi
	cp -r $(GRUB_SRC)-efi $(GRUB_SRC)-bios

$(GRUB_SRC)-efi/grub-install: $(GRUB_SRC)-efi/README
	cd $(GRUB_SRC)-efi && \
	echo depends bli part_gpt > grub-core/extra_deps.lst && \
	./autogen.sh && \
	./configure --target=x86_64 --with-platform=efi && \
	make -j $(shell nproc)

$(GRUB_SRC)-bios/grub-install: $(GRUB_SRC)-bios/README
	cd $(GRUB_SRC)-bios && \
	echo depends bli part_gpt > grub-core/extra_deps.lst && \
	./autogen.sh && \
	./configure --target=i386 --with-platform=pc && \
	make -j $(shell nproc)


$(LINUX_SRC)/README:
	wget https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_SRC).tar.xz
	tar xf $(LINUX_SRC).tar.xz
	cp linux_config $(LINUX_SRC)/.config

$(BZIMAGE): $(LINUX_SRC)/.config linux_config
	cd $(LINUX_SRC) && make -j $(shell nproc)


$(BUSYBOX_SRC)-$(BUSYBOX_REL)/README:
	wget "https://www.busybox.net/downloads/$(BUSYBOX_SRC)-$(BUSYBOX_REL).tar.bz2"
	tar xf $(BUSYBOX_SRC)-$(BUSYBOX_REL).tar.bz2
	cd $(BUSYBOX_SRC)-$(BUSYBOX_REL) && patch -p1 < ../patches/busybox*

$(BUSYBOX_SRC)-$(BUSYBOX_REL)/_install: $(BUSYBOX_SRC)-$(BUSYBOX_REL)/README busybox_config
	cp busybox_config $(BUSYBOX_SRC)-$(BUSYBOX_REL)/.config
	cd $(BUSYBOX_SRC)-$(BUSYBOX_REL) && make -j $(shell nproc) && make install

espmnt:
	mkdir espmnt

rootmnt:
	mkdir rootmnt

hdimage.img: espmnt rootmnt $(GRUB_SRC)-bios/grub-install $(GRUB_SRC)-efi/grub-install $(BZIMAGE) $(BUSYBOX_SRC)-$(BUSYBOX_REL)/_install
	# create image, gpt label and partitions
	dd if=/dev/zero of=hdimage.img bs=1M count=512
	cat hdimage.sfdisk | sfdisk hdimage.img
	kpartx -av hdimage.img
	# format filesystems
	mkfs.fat -F32 /dev/mapper/loop0p2
	mkfs.ext4 -L asdroot /dev/mapper/loop0p3
	# correct loops and mount them
	losetup /dev/loop1 /dev/mapper/loop0p2
	losetup /dev/loop2 /dev/mapper/loop0p3
	mount /dev/loop1 espmnt
	mount /dev/loop2 rootmnt
	# copy base files
	cp -r root/* rootmnt/
	#   install busybox
	cp -r $(BUSYBOX_SRC)-$(BUSYBOX_REL)/_install/* rootmnt/
	#   install kernel
	cp $(BZIMAGE) rootmnt/boot/vmlinuz
	# install UEFI bootloader
	./$(GRUB_SRC)-efi/grub-install --target=x86_64-efi --directory=$(GRUB_SRC)-efi/grub-core --efi-directory=$(shell pwd)/espmnt/ --bootloader-id=GRUB --modules="normal part_msdos part_gpt multiboot" --root-directory=$(shell pwd)/rootmnt/ --no-floppy --removable /dev/loop0
	# install BIOS bootloader
	./$(GRUB_SRC)-bios/grub-install --target=i386-pc --directory=$(GRUB_SRC)-bios/grub-core --root-directory=$(shell pwd)/rootmnt/ --modules="normal part_msdos part_gpt multiboot" --no-floppy /dev/loop0
	
	# unmount
	umount espmnt
	umount rootmnt
	losetup -d /dev/loop1
	losetup -d /dev/loop2
	kpartx -d hdimage.img

.PHONY: clean cleanimg uefitest biostest
cleanimg:
	rm -f hdimage.img

clean: cleanimg
	rm -rf $(GRUB_SRC)-efi $(GRUB_SRC)-bios $(LINUX_SRC) $(BUSYBOX_SRC) rootmnt

uefitest: hdimage.img
	qemu-system-x86_64 -m 512m -bios /usr/share/ovmf/OVMF.fd -hda hdimage.img

biostest: hdimage.img
	qemu-system-x86_64 -m 512m -hda hdimage.img





