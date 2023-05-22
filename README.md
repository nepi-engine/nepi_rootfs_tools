# nepi_rootfs_tools #

This README details the Numurus *nepi_rootfs_tools* repository, contents, and installation

## Concepts ##

NEPI-enabled systems can leverage the specialized A/B rootfs scheme for over-the-air complete filesystem updates with automatic fallback recovery. To facillitate this scheme, three separate ROOTFS partitions distributed across various media are employed: An *Init* rootfs and two *Main* rootfs.
### Init Rootfs ###
The NEPI *Init* rootfs is a very basic, stripped-down image with primary responsibility to determine from config. file which of the two *Main* rootfs to load, and then mount and changeroot over to that image. This Init Rootfs is typically generated via a light modification to the stock or native rootfs of the platform on which NEPI is being deployed. As such, it typically resides on the default boot media for that device -- commonly (but not necessarily) an embedded flash disk.

The Init rootfs detects failure to boot the specified *ACTIVE* rootfs (as described below) and **after 3 consecutive failed reboots, automatically switches over to the *INACTIVE* rootfs.**

The config. file that specifies which of the *Main* rootfs to load and where to find that image is located at */opt/nepi/nepi_rootfs_ab_custom_env.sh*

Typically system admins will need to edit that file during initial NEPI bring-up as detailed in the *Installing the Init Rootfs* section below.

### Main Rootfs A/B ###
The "main" rootfs pair A/B typically consist of individual complete NEPI images. The rootfs images may differ due to NEPI version differences or local modifications. The images are generally quite large and complete, and for that reason often reside on external/removable storage media rather than embedded flash. The disk media that hosts these image partitions is specified in the Init Rootfs *nepi_rootfs_ab_custom_env.sh*

For any given boot up one of the A/B images is considered the *ACTIVE* image and the other is *INACTIVE*, where that distinction is also specified in the Init Rootfs *nepi_rootfs_ab_custom_env.sh* config. file. NEPI s/w allows for switching the *ACTIVE* and *INACTIVE* images after boot-up, with a reboot required after the switch. This provides advanced s/w deployment and test capabilities including

* Installing an updated image while preserving the previous image as a fallback
* Keeping a pristine copy of the image as INACTIVE while customizing and modifying a "dirty" version
* Regression testing between two versions of software
etc.

## Installing the Init Rootfs ##
This repository contains scripts and tools to convert a stock device Linux O/S to a proper NEPI Init Rootfs. The following instructions assume that you can deploy files to the stock device and execute bash shell commands with root privileges therein. For example SSH/SFTP/SCP access to the root user account of the device (or one with *sudo* privileges) satisfies these requirements. Depending on the stock O/S you may also be able to run a graphical environment to achieve the same. To install NEPI Init Rootfs.

The installation script assumes a *systemd*-based init system and a standard Debian-like filesystem layout. If your stock O/S does not meet these requirements, you will need to inspect and customize for your system.

### Installation Steps ###
1. Boot the device into the stock O/S and copy the *nepi_init_rootfs* folder from this repository to a convenient filesystem location on the device.
2. Open a terminal on the device (SSH or native), navigate to the *nepi_init_rootfs* folder and run the *setup_nepi_init_rootfs.sh* script as root.
    ```
    $ sudo ./setup_nepi_init_rootfs.sh
    ```

3. As directed by the script exit message, edit the file at */opt/nepi/nepi_rootfs_ab_custom_env.sh* to provide the desired deployment of Main A/B Rootfs. You do not need to deploy the A/B images to the desired media yet (or even attach the media), though note that for each boot cycle you complete where these conditions are not met, the value in the file */opt/nepi/nepi_boot_failure_count.txt* is incremented and after 3 consecutive increments, the next boot cycle will switch the *ACTIVE* and *INACTIVE* definitions in *nepi_rootfs_ab_custom_env.sh*
4. Reboot the system. On success,
    * Graphical environment (if available) loads a NEPI-specific background and a Desktop text file indicating that "This is not your root filesystem."
    * Default static IP address is 192.168.179.103. You may need to do host-side IP alias setup to reach the device.
    * If a proper Main Rootfs A/B media is installed with NEPI images deployed to the appropriate partitions, the system will boot to the *ACTIVE* rootfs.

## Installing the Main A/B Rootfs from Complete Image ##
The A/B rootfs partition media specified in *nepi_rootfs_ab_custom_env.sh* must be loaded with valid NEPI images (at the very least the *ACTIVE* partition must contain a valid image, but **it is strongly suggested that both partitions contain valid NEPI iomages, even if the initial images are identical**.

The first step with fresh media is to prepare the partitions. This can be done at the command-line (using *parted*, *fdisk*, etc.) or from within a graphical environment (using *gparted*, *disks*, etc.) and can be performed from a host development system (with appropriate interface for the media type) or from the NEPI device's Init Rootfs. The actual steps to partition your (media) are outside the scope of this document, but do note the following guidelines:
* EXT4 is the *strongly* preferred filesystem type for each partitions
* Labels are not necessary, but if used should be "ROOTFS_A" and "ROOTFS_B"
* Each partition should be at least **32GB** in size
* The partitions need not reside on the same physical media so long as their individual definitions in *nepi_rootfs_ab_custom_env.sh* are accurate. Most users will choose to keep these partitions on the same physical disk.
* It is convenient (but not strictly necessary) to assign whatever space remains on the physical media to a third "DATA" partition, also EXT4.

Once the media are partitioned properly, the NEPI main filesystem images can be deployed. **Initial** deployment requires a disk-copy utility, e.g. *dd* and access to both the NEPI raw image file and the partitioned disks from the same system. This can require a bit of logic acrobatics depending on specific host and device configuration. Here are some example steps for a NEPI device with a 128GB SSD attached and a NEPI image file downloaded and decompressed on a host system:

### Sample Partition and Deploy Steps ###
In the following scenario, the SSD is identified by the Init Rootfs as /dev/nvme0n1
1. With the storage media attached to the device, power it up to boot to the Init Rootfs
2. From an SSH terminal to the device (at default IP addr 192.168.179.103), launch the *fdisk* utility
    ```
    $ sudo fdisk /dev/nvme0n1
    ```
to check and configure the SSD

3. (Optional, but suggested) Ensure that any existing partitions are deleted using the *l* and *d* commands
4. Follow fdisk menu options (*m* will print the help menu) to create the three partitions. Make sure that you
    * Create a GPT partition table if this is a new disk
    * Use default start sectors
    * When prompted for partition sizes, use *+32G* (or larger) for A/B partitions. The final "DATA" partition can be the remaining space on the SSD
    * Make sure to write the table and exit with *w* command
5. Mount the third partition (DATA) to provide a local staging location for the NEPI system image
    ```
    $ sudo mkdir /mnt/tmp && sudo mount /dev/nvme0n1p3 /mnt/tmp
    ```
6. Copy the NEPI image file from the host system to the device's */mnt/tmp* directory, e.g. via SCP or a graphical file transfer client app.
7. Deploy the image to the A and B partitions
    ```
    $ sudo dd if=/mnt/tmp/nepi_rootfs.img.raw of=/dev/nvme0n1p1 bs=64M status=progress
    $ sudo dd if=/mnt/tmp/nepi_rootfs.img.raw of=/dev/nvme0n1p2 bs=64M status=progress
    $ sudo rm /mnt/tmp/nepi_rootfs.img.raw
    ```
where the image filename *nepi_rootfs.img.raw* should be customized as necessary.
8. Following successful copy of the images to the A and B partitions, reboot the device. The system should boot into the ACTIVE partition with a complete NEPI deployment running. The NEPI RUI should be accessible from a host web browser at http://192.168.179.103:5003

### Further Updates to A/B Partitions ###
Once the initial deployment succeeds, NEPI onboard tools can be used to streamline the process of updating and reverting software. Consult NEPI software update documentation for additional details.

Note that at this point if you require further filesystem customization outside of the scope provided by the NEPI RUI or NEPI SDK/API, SSH access requires key-based authentication, so you should consult additional NEPI SSH documentation.

## Constructing the Main A/B Rootfs from a Base Image ##
The Main NEPI image is generally deployed as a complete system image licensed and downloaded from Numurus, but this repository also contains tools for building the base image from a stock O/S image (e.g., Ubuntu). Consult the *README.md* in the *nepi_main_rootfs* subdirectory for details.

## Reverting to Init Rootfs ##
At times it may be convenient to revert to an *Init* rootfs. In general this requires ensuring that the Init rootfs cannot find a proper *Main* rootfs to switch over to during boot. You can accomplish that, for example, by

* Removing the media for the *Main/Active* rootfs
* From the *Active* rootfs, mount the *Init* rootfs image and edit the *nepi_rootfs_ab_custom_env.sh* file to comment out the A/B partition locations
