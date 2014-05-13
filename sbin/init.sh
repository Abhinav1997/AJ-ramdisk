#!/sbin/busybox sh
set +x
_PATH="$PATH"
export PATH=/sbin

busybox cd /
busybox date >>boot.txt
exec >>boot.txt 2>&1
busybox rm /init

# include device specific vars
source /sbin/bootrec-device

# create directories
busybox mkdir -m 755 -p /dev/block
busybox mkdir -m 755 -p /dev/input
busybox mkdir -m 555 -p /proc
busybox mkdir -m 755 -p /sys

# create device nodes
busybox mknod -m 600 /dev/block/mmcblk0 b 179 0
busybox mknod -m 600 ${BOOTREC_EVENT_NODE}
busybox mknod -m 666 /dev/null c 1 3

# mount filesystems
busybox mount -t proc proc /proc
busybox mount -t sysfs sysfs /sys

# trigger device specific LED
if [ -e /sbin/bootrec-led ]
then
	./sbin/bootrec-led
fi

# keycheck
busybox cat ${BOOTREC_EVENT} > /dev/keycheck&
busybox sleep 3

# android ramdisk
load_image=/sbin/ramdisk.cpio

# boot decision
if [ -s /dev/keycheck ] || busybox grep -q warmboot=0x5502 /proc/cmdline; then
	busybox echo 'RECOVERY BOOT' >>boot.txt
	# recovery ramdisk

	##Handle multiple recovery ramdisks based on keypress
	# Thanks a lot to the great DooMLoRD
	# default recovery ramdisk is PhilZ 
	load_image=/sbin/ramdisk-recovery-philz.cpio

	if [ -s /dev/keycheck ]
	then
		busybox hexdump < /dev/keycheck > /dev/keycheck1

		export VOLUKEYCHECK=`busybox cat /dev/keycheck1 | busybox grep '0001 0073'`
		export VOLDKEYCHECK=`busybox cat /dev/keycheck1 | busybox grep '0001 0072'`

		busybox rm /dev/keycheck
		busybox rm /dev/keycheck1

		if [ -n "$VOLUKEYCHECK" ]
		then
			#load philz ramdisk		
			load_image=/sbin/ramdisk-recovery-philz.cpio
		fi

		if [ -n "$VOLDKEYCHECK" ]
		then
			#load twrp ramdisk
			load_image=/sbin/ramdisk-recovery-twrp.cpio
		fi
	fi
else
	busybox echo 'ANDROID BOOT' >>boot.txt
fi

# kill the keycheck process
busybox pkill -f "busybox cat ${BOOTREC_EVENT}"

busybox umount /proc
busybox umount /sys

busybox rm -fr /dev/*
busybox date >>boot.txt

# unpack the ramdisk image
# -u should be used to replace the static busybox with dynamically linked one.
busybox cpio -ui < ${load_image}

export PATH="${_PATH}"
exec /init
