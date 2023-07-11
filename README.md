# nepi_rootfs_tools #

This README details the Numurus *nepi_rootfs_tools* repository, contents, and installation

## Concepts ##

NEPI-enabled systems can leverage the specialized A/B rootfs scheme for over-the-air complete filesystem updates with automatic fallback recovery. To facillitate this scheme, three separate ROOTFS partitions distributed across various media are employed: An *INIT* rootfs and two *Main* rootfs.
### INIT Rootfs ###
The NEPI *INIT* rootfs is a very basic, stripped-down image with primary responsibility to determine from config. file which of the two *Main* rootfs to load, and then mount and changeroot over to that image. This INIT Rootfs is typically generated via a light modification to the stock or native rootfs of the platform on which NEPI is being deployed. As such, it typically resides on the default boot media for that device -- commonly (but not necessarily) an embedded flash disk.

The INIT rootfs detects failure to boot the specified *ACTIVE* rootfs (as described below) and **after 3 consecutive failed reboots, automatically switches over to the *INACTIVE* rootfs.**

The config. file that specifies which of the *Main* rootfs to load and where to find that image is located at */opt/nepi/nepi_rootfs_ab_custom_env.sh*

Typically system admins will need to edit that file during initial NEPI bring-up as detailed in the *Installing the INIT Rootfs* section below.

### Main Rootfs A/B ###
The "main" rootfs pair A/B typically consist of individual complete NEPI images. The rootfs images may differ due to NEPI version differences or local modifications. The images are generally quite large and complete, and for that reason often reside on external/removable storage media rather than embedded flash. The disk media that hosts these image partitions is specified in the INIT Rootfs *nepi_rootfs_ab_custom_env.sh*

For any given boot up one of the A/B images is considered the *ACTIVE* image and the other is *INACTIVE*, where that distinction is also specified in the INIT Rootfs *nepi_rootfs_ab_custom_env.sh* config. file. NEPI s/w allows for switching the *ACTIVE* and *INACTIVE* images after boot-up, with a reboot required after the switch. This provides advanced s/w deployment and test capabilities including

* Installing an updated image while preserving the previous image as a fallback
* Keeping a pristine copy of the image as INACTIVE while customizing and modifying a "dirty" version
* Regression testing between two versions of software
etc.

## Installing the INIT Rootfs ##
This repository contains scripts and tools to convert a stock device Linux O/S to a proper NEPI INIT Rootfs. The following instructions assume that you can deploy files to the stock device and execute bash shell commands with root privileges therein. For example SSH/SFTP/SCP access to the root user account of the device (or one with *sudo* privileges) satisfies these requirements. Depending on the stock O/S you may also be able to run a graphical environment to achieve the same. To install NEPI INIT Rootfs.

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

The first step with fresh media is to prepare the partitions. This can be done at the command-line (using *parted*, *fdisk*, etc.) or from within a graphical environment (using *gparted*, *disks*, etc.) and can be performed from a host development system (with appropriate interface for the media type) or from the NEPI device's INIT Rootfs. The actual steps to partition your (media) are outside the scope of this document, but do note the following guidelines:
* EXT4 is the *strongly* preferred filesystem type for each partitions
* Labels are not necessary, but if used should be "ROOTFS_A" and "ROOTFS_B"
* Each partition should be at least **32GB** in size
* The partitions need not reside on the same physical media so long as their individual definitions in *nepi_rootfs_ab_custom_env.sh* are accurate. Most users will choose to keep these partitions on the same physical disk.
* It is convenient (but not strictly necessary) to assign whatever space remains on the physical media to a third "DATA" partition, also EXT4.

Once the media are partitioned properly, the NEPI main filesystem images can be deployed. **Initial** deployment requires a disk-copy utility, e.g. *dd* and access to both the NEPI raw image file and the partitioned disks from the same system. This can require a bit of logic acrobatics depending on specific host and device configuration. Here are some example steps for a NEPI device with a 128GB SSD attached and a NEPI image file downloaded and decompressed on a host system:

### Sample Partition and Deploy Steps ###
In the following scenario, the SSD is identified by the INIT Rootfs as /dev/nvme0n1
1. With the storage media attached to the device, power it up to boot to the INIT Rootfs
2. From an SSH terminal to the device (at default IP addr 192.168.179.103), launch the *fdisk* utility
    ```
    $ sudo fdisk /dev/nvme0n1
    ```
to check and configure the SSD

3. (Optional, but suggested) Ensure that any existing partitions are deleted using the *l* and *d* commands
4. Follow fdisk menu options (*m* will print the help menu) to create the three partitions. Make sure that you
    * Create a GPT partition table if this is a new disk
    * Use default start sectors
    * When prompted for partition sizes, use *+30G* (or larger) for A/B partitions. The final "DATA" partition can be the remaining space on the SSD
    * Make sure to write the table and exit with *w* command
5. Mount the third partition (DATA) to provide a local staging location for the NEPI system image
    ```
    $ sudo mkdir /mnt/tmp && sudo mount /dev/nvme0n1p3 /mnt/tmp
    ```
6. Copy the NEPI image file from the host system to the device's */mnt/tmp* directory, e.g. via SCP or a graphical file transfer client app. This image can be the same base image that was used in "Installing the INIT ROOTFS" above or it can be an existing NEPI-preinstalled image for your particular platform.
7. Deploy the image to the A and B partitions
    ```
    $ sudo dd if=/mnt/tmp/nepi_rootfs.img.raw of=/dev/nvme0n1p1 bs=64M status=progress
    $ sudo dd if=/mnt/tmp/nepi_rootfs.img.raw of=/dev/nvme0n1p2 bs=64M status=progress
    $ sudo rm /mnt/tmp/nepi_rootfs.img.raw
    ```
where the image filename *nepi_rootfs.img.raw* should be customized as necessary.
8. It is a good idea here to resize the ROOTFS filesystems for the entire partition size you set in step 4. above so that you can use the full partition size for filesystem additions.
    ```
    $ sudo e2fsck -f /dev/nvme0n1p1
    $ sudo resize2fs /dev/nvme0n1p1
    $ sudo e2fsck -f /dev/nvme0n1p2
    $ sudo resize2fs /dev/nvme0n1p2
    ```
9. Following successful copy of the images to the A and B partitions, reboot the device. The system should boot into the ACTIVE partition with a complete NEPI deployment running. The NEPI RUI should be accessible from a host web browser at http://192.168.179.103:5003

### Further Updates to A/B Partitions ###
Once the initial deployment succeeds, NEPI onboard tools can be used to streamline the process of updating and reverting software. Consult NEPI software update documentation for additional details.

Note that at this point if you require further filesystem customization outside of the scope provided by the NEPI RUI or NEPI SDK/API, SSH access requires key-based authentication, so you should consult additional NEPI SSH documentation.

## Constructing the Main A/B Rootfs from a Base Image ##
The Main NEPI image is most commonly deployed as a complete system image licensed and downloaded from Numurus, but this repository also contains tools for building the base image from a stock O/S image (e.g., Ubuntu). Those steps are detailed here.

Within the *nepi_main_rootfs* subdirectory of this repository are a collection of shell scripts that automate building the NEPI *Main* rootfs as a series of installation steps. In general, these scripts are hierarchical, so only the most specialized one must be explicitly called and it will call the less specialized scripts as necessary. The installation scripts perform a few basic steps:
* Installation of NEPI dependencies from Debian packages
* Establishment of NEPI installation directories and system-level config. files, principally at */opt/nepi*
* System level configuration by establishing symlinks from standard configuration files (e.g., */etc/hostname*) to files within the */opt/nepi* folder

At present, these scripts assume a standard Debian/Ubuntu starting point with an appropriate hardware package BSP pre-installed, and require network connectivity for the device. Eventually, the script set may include a larger set of hardware and base O/S options, but for now the scripts should be considered a read-only reference for anyone attempting to install NEPI on a different hardware or base O/S or from cached dependency packages.

### Example NEPI bring-up for Numurus S2X ###
The Numurus S2X Smart System Platform provides a pre-installed, pre-configured NEPI hardware/software platform, which runs an Nvidia Jetson on a ConnectTech Boson carrier. The following steps describe the current bring-up process. The assumed hardware is a ConnectTech Boson carrier with Nvidia Jetson Xavier-NX daughter board (module, not dev-kit version) with SSD attached (storage capacity at least 128GB)

1. Install complete Boson BSP for ConnectTech Boson with Nvidia Jetson Xavier-NX to the device EMMC (embedded flash) per ConnectTech Release Notes: 

https://connecttech.com/product/boson-for-framos-carrier-board-for-nvidia-jetson-xavier-nx/

**Note that this step requires a physical Ubuntu x86/x86-64 host system (VM does not work due to issues with USB image transfer mechanism)**

2. From the device graphical interface, complete all steps for the stock Ubuntu installation using the following options:
    * Name: NEPI
    * Computer Name: nepi-init-rootfs
    * Username: nepi
    * Password: nepi
    * Auto-login Enabled

3. Follow directions from *Installing the INIT Rootfs* section of this document to install the NEPI *INIT* Rootfs. Make sure to check and edit if necessary the */opt/nepi/nepi_rootfs_ab_custom_env.sh* file for the SSD A/B/Data partitions you are about to create.

4. Follow SSD partitioning directions from *Sample Partition and Deploy Steps* section of this document, using the same base O/S from step 1. as the deployed image file for just the initial *ACTIVE* Rootfs partitions as specified in *nepi_rootfs_ab_custom_env.sh*. (You can find this image at *Linux_for_Tegra/bootloader/system.img.raw* 

5. Reboot the system and verify that you are back up in a base Ubuntu O/S filesystem, **not** the NEPI *INIT* rootfs. (The NEPI *INIT* rootfs includes a very clear message on the Desktop, a NEPI-specific background image, etc.)

6. From the device graphical interface, complete all steps for the stock Ubuntu installation using the following options:
    * Name: NEPI
    * Computer Name: nepi-s2x
    * Username: nepi
    * Password: nepi
    * Auto-login Disabled

7. From your host system, deploy the contents of the *nepi_main_rootfs* subdirectory of this repo using e.g., *sftp*. You may need to set up a temporary static IP address on the device and enable the default SSH server.

8. From the device, run the top-level installation script:

    ```
    $ sudo ./setup_nepi_s2x_rootfs.sh
    ```

9. Upon successful completion of the script, the current rootfs partition is ready for NEPI s/w build and install, the details of which are (currently) outside the scope of this document.

10. Following complete installation of NEPI s/w, reboot the system and ensure that you can reach the RUI at the default URL

    http://192.168.179.103:5003

If so, this *ACTIVE* partition is ready. 

11. The *INACTIVE* partition must still be prepared. The easiest way to accomplish that is to switch ACTIVE/INACTIVE via the RUI Settings-->Software page and reboot. At that point because the now-*ACTIVE* partition is still empty, the system will fail to change-root to that partition and will revert to the *INIT* rootfs, which you can reach via SSH or graphical environment. The now-*INACTIVE* partition can be copied directly to the *ACTIVE* partition with
    ```
    sudo dd if=/dev/nvme0n1p1 of=/dev/nvme0n1p2 bs=64M status=progress
    ```

12. Upon reboot, the system should start in the newly-*ACTIVE* rootfs, which is now a byte-for-byte copy of the newly-*INACTIVE* rootfs that you generate in step 8.

## Reverting to INIT Rootfs ##
At times it may be convenient to revert to an *INIT* rootfs. In general this requires ensuring that the INIT rootfs cannot find a proper *ACTIVE* rootfs to change-root to during boot. You can accomplish that, for example, by

* Removing the media for the current *ACTIVE* rootfs partition
* OR From the *ACTIVE* rootfs, mount the *INIT* rootfs image and edit the *nepi_rootfs_ab_custom_env.sh* file to comment out the A/B partition locations
