

Base image to construct TI RTOS environments

1. build docker and run it
2. extract rootfs and BOOT into $HOME/workspace/images/rootfs and $HOME/workspace/images/BOOT
3. in rtos root directory, run ./sdk_builder/scripts/setup_psdk_rtos.sh
4. in sdk_builder directory of rtos, do make sdk -j
5. in sdk_builder directory of rtos, do make linux_fs_install_sd
