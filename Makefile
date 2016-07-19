

######################################################################
# Config                                                             #
######################################################################

BUILD_PATH                       = build
ROOTFS_PATH                      = $(BUILD_PATH)/rootfs
PACKET_CACHE_PATH                = $(BUILD_PATH)/apt_cache
MULTISTRAP_CONF_FILE             = $(CONF_PATH)/minimal.conf
POST_ROOTFS_PATH                 = $(CONF_PATH)/post_rootfs
QEMU_BOOL_FILES_PATH             = boot_files
TMP_ROOTFS_MOUNT_POINT           = /mnt/tmp_arm_rootfs
BZ2_ARCHIVE_FILE                 = $(BUILD_PATH)/rootfs.tar.bz2
GZIP_ARCHIVE_FILE                = $(BUILD_PATH)/rootfs.tar.gz

CONF_PATH                        = conf
TARGET_ARCH                      = armhf
TARGET_BLOCK_DEVICE_NAME         = sdc
ROOTFS_PARTITION_NUMBER          = 2
ROOTFS_PARTITION_FILESYSTEM_TYPE = ext3


######################################################################
# Derived variables                                                  #
######################################################################

ROOTFS_SUCC_FILE                 = rootfs_success_file
POST_ROOTFS_SUCC_FILE            = post_rootfs_success_file
TARGET_BLOCK_DEVICE_FILE         = /dev/$(TARGET_BLOCK_DEVICE_NAME)
ROOTFS_BLOCK_DEVICE_FILE         = $(TARGET_BLOCK_DEVICE_FILE)$(ROOTFS_PARTITION_NUMBER)

QEMU_KERNEL_FILE                 = $(QEMU_BOOL_FILES_PATH)/kernel
QEMU_INITRD_FILE                 = $(QEMU_BOOL_FILES_PATH)/initrd



default: build


$(ROOTFS_SUCC_FILE):
	rm -rf $(SUCCESS_FILE)
	@if [ ! -d $(BUILD_PATH) ]; then \
		mkdir -p $(BUILD_PATH); \
	fi
	@if [ ! -d $(PACKET_CACHE_PATH) ]; then \
		mkdir -p $(PACKET_CACHE_PATH); \
	fi
	@multistrap --arch       $(TARGET_ARCH)          \
		    --dir        $(ROOTFS_PATH)          \
		    --file       $(MULTISTRAP_CONF_FILE) \
		    --source-dir $(PACKET_CACHE_PATH)
	@touch $(ROOTFS_SUCC_FILE)

rootfs: $(ROOTFS_SUCC_FILE)

$(BZ2_ARCHIVE_FILE): rootfs
	tar -cvjf $(BZ2_ARCHIVE_FILE) -C $(ROOTFS_PATH) .

rootfs_bz2: $(BZ2_ARCHIVE_FILE)

$(GZIP_ARCHIVE_FILE): rootfs
	tar -cvzf $(GZIP_ARCHIVE_FILE) -C $(ROOTFS_PATH) .

rootfs_gzip: $(GZIP_ARCHIVE_FILE)

rootfs_archive: rootfs_gzip rootfs_bz2

$(POST_ROOTFS_SUCC_FILE): rootfs
	@for POST_FILE in $$(find $(POST_ROOTFS_PATH)); do \
		if [ -d $${POST_FILE} ]; then continue; fi; \
		echo "$${POST_FILE}:"; \
		$${POST_FILE} $(ROOTFS_PATH); \
	done
	@touch $(POST_ROOTFS_SUCC_FILE)

post_rootfs: | rootfs $(POST_ROOTFS_SUCC_FILE)
	cp /usr/bin/qemu-arm-static $(ROOTFS_PATH)/usr/bin
	(cd $(ROOTFS_PATH) && chroot . /bin/bash -c "export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C && /var/lib/dpkg/info/dash.preinst install && dpkg --configure -a && mount proc -t proc /proc && dpkg --configure -a && umount /proc")

#(cd $(ROOTFS_PATH) && chroot . /bin/bash -c "LC_ALL=C LANGUAGE=C LANG=C dpkg --configure -a")
#(cd $(ROOTFS_PATH) && chroot . /bin/bash -c "DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C dpkg --configure dash")

#(cd $(ROOTFS_PATH) && chroot . /bin/bash -c "DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C dpkg --configure -a")

build: | rootfs post_rootfs rootfs_archive

clean:
	rm -rf build/rootfs
	rm -f $(ROOTFS_SUCC_FILE)
	rm -f $(POST_ROOTFS_SUCC_FILE)

deploy:
	@if [ ! -d $(TMP_ROOTFS_MOUNT_POINT) ]; then \
		mkdir -p $(TMP_ROOTFS_MOUNT_POINT); \
	fi
	@test -b $(TARGET_BLOCK_DEVICE_FILE)                                         || (echo "$(TARGET_BLOCK_DEVICE_FILE) is no block device" && exit 1)
	@test $$(cat /sys/block/$(TARGET_BLOCK_DEVICE_NAME)/device/model) = "SD/MMC" || (echo "$(TARGET_BLOCK_DEVICE_NAME) is no SD card"      && exit 1)
	@test -b $(ROOTFS_BLOCK_DEVICE_FILE)                                         || (echo "$(ROOTFS_BLOCK_DEVICE_FILE) is no block device" && exit 1)
	@mkfs.$(ROOTFS_PARTITION_FILESYSTEM_TYPE) $(ROOTFS_BLOCK_DEVICE_FILE)
	@mount $(ROOTFS_BLOCK_DEVICE_FILE) $(TMP_ROOTFS_MOUNT_POINT)
	@cp -arv $(ROOTFS_PATH)/* $(TMP_ROOTFS_MOUNT_POINT)/
	@umount $(ROOTFS_BLOCK_DEVICE_FILE)
	@sync

qemu_boot:
	qemu-system-arm -m 256 -M versatilepb -kernel $(QEMU_KERNEL_FILE) -initrd $(QEMU_INITRD_FILE) -hda $(TARGET_BLOCK_DEVICE_FILE)

#-append "root=/dev/sda1"

# .PHONY
# clean:
# 	echo test
