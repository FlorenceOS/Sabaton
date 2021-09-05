#!/bin/bash

set -e

mkdir -p uefidir/image/EFI/BOOT/
cp $1 uefidir/image/EFI/BOOT/BOOTA64.EFI

qemu-system-aarch64\
	-M virt\
	-m 4G\
	-cpu cortex-a57\
	-serial stdio\
	-device ramfb\
	-drive if=pflash,format=raw,file=/zpool/edk2-aarch64/usr/share/edk2/aarch64/QEMU_EFI.fd,readonly=on\
	-drive if=pflash,format=raw,file=/zpool/edk2-aarch64/usr/share/edk2/aarch64/QEMU_VARS.fd\
	-hdd fat:rw:uefidir/image\
	-usb\
	-device usb-ehci\
	-device usb-kbd\
	-device usb-mouse
