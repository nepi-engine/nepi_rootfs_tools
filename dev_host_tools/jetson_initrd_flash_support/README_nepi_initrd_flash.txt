NEPI requires a custom partition scheme with separate Init Rootfs, Rootfs A, Rootfs B, and Data (user) partitions. This directory includes the XML partition layout file that achieves this.

These instructions are tested on a Orin-NX on Seeed Studios A603 carrier for Jetpack 5.1.2. You may need to adapt them for your specific needs.

1. Obtain the NEPI images, "external.tar.gz". This is a single folder with both the init and main rootfs images, and some other stuff. Also, get the XML file in the same folder. Extract the tar.gz... that will take a long time.
image.png

2. Follow the Seeed Studios Jetpack 5.1.2 (i.e., Linux_for_Tegra 35.4.1) instructions steps 1-4 only:
   https://wiki.seeedstudio.com/reComputer_A603_Flash_System/
At that point you have the proper version of Jetpack installed on your host with the proper A603 board support package.

The following steps all assume you are in the Linux_for_Tegra directory.

3. Copy the "flash_l4t_t234_nvme_nepi_custom.xml" file to "./tools/kernel_flash"
[This defines our NEPI-custom SSD partition layout and the files to write to each of the partitions. This layout relies on a 2TB SSD and 16GB-exactly init rootfs image and 30GB-exactly main rootfs image; any changes there require some adjustment to the XML file]

4. Build the QSPI "internal" components:
$ sudo ./tools/kernel_flash/l4t_initrd_flash.sh --showlogs -p "-c bootloader/t186ref/cfg/flash_t234_qspi.xml" --no-flash --network usb0 p3509-a02+p3767-0000 internal
This results in a folder at "./tools/kernel_flash/images/internal"

5. Move the entire untar'd "external" folder to "./tools/kernel_flash/images"
[This avoids the "external" build step, which takes a long time to build a stock rootfs, even though we aren't using it.]

6. Run the "flash-only" command:
$ sudo ./tools/kernel_flash/l4t_initrd_flash.sh --external-device nvme0n1p1 -p "-c ./bootloader/t186ref/cfg/flash_t234_qspi.xml" -c ./tools/kernel_flash/flash_l4t_t234_nvme_nepi_custom.xml --showlogs --flash-only --network usb0 p3509-a02+p3767-0000 nvme0n1p1
[This takes a long time! Should end with console output like:
Flash is successful
Reboot device
Cleaning up...
Log is saved to Linux_for_Tegra/initrdlog/flash_1-2_0_20231127-154607.log]

7. Remove the jumper (if applicable) and power cycle. Should boot to NEPI main rootfs 2.1.1 with RUI available, etc.

8. SSH in and turn the large unassigned "DATA" partition (i.e., nepi_storage) into a proper filesystem with
$ sudo mkfs.ext4 /dev/nvme0n1p4
and reboot. After the system comes back up, ensure that the RUI Dashboard reports a large size for this partition... something close to 2TB.

The next time as long as you are on the same host, you can skip steps 1-5 and run steps 6-8.

If you need to update NEPI main rootfs with a new image to flash a fresh target, you'll simply replace the main rootfs image (preserving its same file name) in the "external" folder with the updated one and rerun steps 6-8.
