

######################################################################
# Config                                                             #
######################################################################

ROOTFS_PATH                      = $(BUILD_PATH)/rootfs
PACKET_CACHE_PATH                = $(BUILD_PATH)/apt_cache
MULTISTRAP_CONF_FILE             = $(CONF_PATH)/minimal.conf
TMP_ROOTFS_MOUNT_POINT           = /mnt/tmp_arm_rootfs
QEMU_BOOL_FILES_PATH             = boot_files

CONF_PATH                        = conf
TARGET_ARCH                      = armhf
BUILD_PATH                       = build
TARGET_BLOCK_DEVICE_NAME         = sdc
ROOTFS_PARTITION_NUMBER          = 2
ROOTFS_PARTITION_FILESYSTEM_TYPE = ext4


######################################################################
# Derived variables                                                  #
######################################################################

SUCCESS_FILE                     = success_file
TARGET_BLOCK_DEVICE_FILE         = /dev/$(TARGET_BLOCK_DEVICE_NAME)
ROOTFS_BLOCK_DEVICE_FILE         = $(TARGET_BLOCK_DEVICE_FILE)$(ROOTFS_PARTITION_NUMBER)

QEMU_KERNEL_FILE                 = $(QEMU_BOOL_FILES_PATH)/kernel
QEMU_INITRD_FILE                 = $(QEMU_BOOL_FILES_PATH)/initrd

default: build

$(SUCCESS_FILE):
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
	touch $(SUCCESS_FILE)

build: $(SUCCESS_FILE)

deploy:
	@if [ ! -d $(TMP_ROOTFS_MOUNT_POINT) ]; then \
		mkdir -p $(TMP_ROOTFS_MOUNT_POINT); \
	fi
	@test -b $(TARGET_BLOCK_DEVICE_FILE)                                         || (echo "$(TARGET_BLOCK_DEVICE_FILE) is no block device" && exit 1)
	@test $$(cat /sys/block/$(TARGET_BLOCK_DEVICE_NAME)/device/model) = "SD/MMC" || (echo "$(TARGET_BLOCK_DEVICE_NAME) is no SD card"      && exit 1)
	@test -b $(ROOTFS_BLOCK_DEVICE_FILE)                                         || (echo "$(ROOTFS_BLOCK_DEVICE_FILE) is no block device" && exit 1)
	@eatmydata mkfs.$(ROOTFS_PARTITION_FILESYSTEM_TYPE) $(ROOTFS_BLOCK_DEVICE_FILE)
	@mount $(ROOTFS_BLOCK_DEVICE_FILE) $(TMP_ROOTFS_MOUNT_POINT)
	@eatmydata cp -arv $(ROOTFS_PATH)/* $(TMP_ROOTFS_MOUNT_POINT)/
	@exit 1
	@umount $(ROOTFS_BLOCK_DEVICE_FILE)
	@sync

qemu_boot:
	qemu-system-arm -m 256 -M versatilepb -kernel $(QEMU_KERNEL_FILE) -initrd $(QEMU_INITRD_FILE) -hda $(TARGET_BLOCK_DEVICE_FILE)

#-append "root=/dev/sda1"

# .PHONY
# clean:
# 	echo test
