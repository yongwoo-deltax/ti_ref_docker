#! /bin/sh
# Script to create SD card for J7 evm.
#
# Author: Brijesh Singh, Texas Instruments Inc.
#       : Adapted for dra8xx-evm by Nikhil Devshatwar, Texas Instruments Inc.
#
# Licensed under terms of GPLv2
#

VERSION="0.2"

export LANG=C

# Determine the absolute path to the executable
# EXE will have the PWD removed so we can concatenate with the PWD safely
PWD=`pwd`
EXE=`echo $0 | sed s=$PWD==`
EXEPATH="$PWD"/"$EXE"
clear

version ()
{
  echo
  echo "`basename $1` version $VERSION"
  echo "Script to create bootable SD card for Linux"
  echo

  exit 0
}

usage ()
{
  echo "
Usage: `basename $1` <options> [ files for install partition ]

Mandatory options:
  --device              SD block device node (e.g /dev/sdd)

Optional options:
  --sdk                 Path to SDK directory
  --version             Print version.
  --help                Print this help message.
"
  exit 1
}

check_if_main_drive ()
{
  mount | grep " on / type " > /dev/null
  if [ "$?" != "0" ]
  then
    echo "-- WARNING: not able to determine current filesystem device"
  else
    main_dev=`mount | grep " on / type " | awk '{print $1}'`
    echo "-- Main device is: $main_dev"
    echo $main_dev | grep "$device" > /dev/null
    [ "$?" = "0" ] && echo "++ ERROR: $device seems to be current main drive ++" && exit 1
  fi

}

check_if_big_size ()
{
  partname=`basename $device`
  size=`cat /proc/partitions | grep $partname | head -1 | awk '{print $3}'`
  if [ $size -gt 17000000 ]; then
    cat << EOM

************************* WARNING ***********************************
*                                                                   *
*      Selected Device is greater then 16GB                         *
*      Continuing past this point will erase data from device       *
*      Double check that this is the correct SD Card                *
*                                                                   *
*********************************************************************
EOM

    ENTERCORRECTLY=0
    while [ $ENTERCORRECTLY -ne 1 ]
    do
      read -p 'Would you like to continue [y/n] : ' SIZECHECK
      echo ""
      echo " "
      ENTERCORRECTLY=1
      case $SIZECHECK in
        "y")  ;;
        "n")  exit;;
        *)  echo "Please enter y or n";ENTERCORRECTLY=0;;
      esac
      echo ""
    done
  fi
}

unmount_all_partitions ()
{
  for i in `ls -1 $device*`; do
    echo "unmounting device '$i'"
    umount $i 2>/dev/null
  done
  mount | grep $device
}

#copy/paste programs
cp_progress ()
{
	CURRENTSIZE=0
	while [ $CURRENTSIZE -lt $TOTALSIZE ]
	do
		TOTALSIZE=$1;
		TOHERE=$2;
		CURRENTSIZE=`sudo du -s $TOHERE | awk {'print $1'}`
		echo -e -n "$CURRENTSIZE /  $TOTALSIZE copied \r"
		sleep 1
	done
}

# Check if the script was started as root or with sudo
user=`id -u`
[ "$user" != "0" ] && echo "++ Must be root/sudo ++" && exit

# Process command line...
while [ $# -gt 0 ]; do
  case $1 in
    --help | -h)
      usage $0
      ;;
    --device) shift; device=$1; shift; ;;
    --version) version $0;;
    *) copy="$copy $1"; shift; ;;
  esac
done

test -z $device && usage $0

if [ ! -b $device ]; then
   echo "ERROR: $device is not a block device file"
   exit 1;
fi

check_if_main_drive

check_if_big_size

echo "************************************************************"
echo "*         THIS WILL DELETE ALL THE DATA ON $device         *"
echo "*                                                          *"
echo "*         WARNING! Make sure your computer does not go     *"
echo "*                  in to idle mode while this script is    *"
echo "*                  running. The script will complete,      *"
echo "*                  but your SD card may be corrupted.      *"
echo "*                                                          *"
#echo "*         Press <ENTER> to confirm....                     *"
echo "************************************************************"
#read junk

udevadm control -s
unmount_all_partitions

dd if=/dev/zero of=$device bs=1024 count=1024 status=progress

sync

cat << END | fdisk $device
n
p
1

+128M
n
p
2


t
1
c
a
1
w
END

unmount_all_partitions
sleep 3

# handle various device names.
PARTITION1=${device}1
if [ ! -b ${PARTITION1} ]; then
        PARTITION1=${device}p1
fi

PARTITION2=${device}2
if [ ! -b ${PARTITION2} ]; then
        PARTITION2=${device}p2
fi

# make partitions.
echo "Formatting ${device} ..."
if [ -b ${PARTITION1} ]; then
	mkfs.vfat -F 32 -n "boot" ${PARTITION1}
else
	echo "Cant find boot partition in /dev"
fi

if [ -b ${PARITION2} ]; then
	mkfs.ext4 -L "rootfs" ${PARTITION2}
else
	echo "Cant find rootfs partition in /dev"
fi

echo "Partitioning and formatting completed!"
mount | grep $device

echo "Copying filesystem on $PARTITION1, $PARTITION2"

export PATH_TO_SDBOOT=$PWD/tmp/BOOT
export PATH_TO_SDROOTFS=$PWD/tmp/rootfs

mkdir -p $PATH_TO_SDBOOT
mkdir -p $PATH_TO_SDROOTFS

sudo mount -t vfat $PARTITION1 $PATH_TO_SDBOOT
sudo mount -t ext4 $PARTITION2 $PATH_TO_SDROOTFS

FS_BOOT="$PWD/BOOT"
FS_KERNEL="$PWD/kernelfs"
FS_ROOT="$PWD/rootfs"
# FOLDERSIZE=4

if [ -d $FS_BOOT ]
then
  echo ""
  echo "Copying boot partition"
  sudo chown -R root:root $FS_BOOT
  sudo rsync -ah --info=progress2 $FS_BOOT/* $PATH_TO_SDBOOT 
fi

if [ -d $FS_ROOT ]
then
  echo ""
  echo "Copying rootfs System partition"
  sudo chown -R root:root $FS_ROOT
  # TOTALSIZE=`sudo du -s $FS_ROOT | awk {'print $1'}`
  # TOTALSIZE=`expr $TOTALSIZE - $FOLDERSIZE`
  # sudo cp -r $FS_ROOT/* $PATH_TO_SDROOTFS & cp_progress $TOTALSIZE $PATH_TO_SDROOTFS
  sudo rsync -ah --info=progress2 $FS_ROOT/* $PATH_TO_SDROOTFS
fi

if [ -d $FS_KERNEL ]
then
  echo ""
  echo "Copying kernel image"
  sudo rsync -ah --info=progress2 $FS_KERNEL/* $PATH_TO_SDROOTFS
fi

echo ""
echo "unmounting $PARTITION1, $PARTITION2"
echo ""

sudo umount $PATH_TO_SDBOOT
sudo umount $PATH_TO_SDROOTFS

sudo rm -rf  $PWD/tmp

udevadm control -S

echo ""
echo "completed!"
echo ""
sync
sync
