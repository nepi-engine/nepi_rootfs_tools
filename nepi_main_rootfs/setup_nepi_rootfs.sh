#!/bin/sh

# Set up the NEPI Standard ROOTFS (Typically on External Media (e.g SD, SSD, SATA))

# This script is tested to run from a fresh Ubuntu 18.04 install based on the L4T reference rootfs.
# Other base rootfs schemes may work, but should be tested.

# Settable values
ROS_VERSION=melodic

# Preliminary checks
# Internet connectivity:
sudo dhclient
if ! ping -c 2 google.com; then
    echo "ERROR: System must have internet connection to proceed"
    exit 1
fi

# The script is assumed to run from a directory structure that mirrors the Git repo it is housed in.
HOME_DIR=$PWD

# Clear the Desktop
rm /home/nepi/Desktop/*

# Create the directory structure for NEPI -- lots of stuff gets installed here
sudo mkdir -p /opt/nepi
sudo mkdir -p /opt/nepi/ros
sudo mkdir -p /opt/nepi/nepi_link
# And hand all these over to nepi user
sudo chown -R nepi:nepi /opt/nepi

# Generate the entire config directory -- this is where all the targets of Linux config symlinks
# generated below land
sudo cp -r ${HOME_DIR}/config /opt/nepi

# Set up the default hostname
# Hostname Setup - the link target file may be updated by NEPI specialization scripts, but no link will need to move
sudo mv /etc/hostname /etc/hostname.bak
sudo ln -sf /opt/nepi/config/etc/hostname /etc/hostname

# Update the Desktop background image
echo "Updating Desktop background image"
sudo mkdir -p /opt/nepi/resources
sudo cp ${HOME_DIR}/resources/nepi_wallpaper.png /opt/nepi/resources/
sudo chown nepi:nepi /opt/nepi/resources/nepi_wallpaper.png
gsettings set org.gnome.desktop.background picture-uri file:////opt/nepi/resources/nepi_wallpaper.png

# Update the login screen background image - handled by a sys. config file
echo "Updating login screen background image"
sudo mv /usr/share/gnome-shell/theme/ubuntu.css /usr/share/gnome-shell/theme/ubuntu.css.bak
sudo ln -sf /opt/nepi/config/usr/share/gnome-shell/theme/ubuntu.css /usr/share/gnome-shell/theme/ubuntu.css

# Set up static IP addr.
sudo mv /etc/network/interfaces.d /etc/network/interfaces.d.bak
sudo ln -sf /opt/nepi/config/etc/network/interfaces.d /etc/network/interfaces.d

# Set up SSH
sudo mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo ln -sf /opt/nepi/config/etc/ssh/sshd_config /etc/ssh/sshd_config
# And link default public key - Make sure all ownership and permissions are as required by SSH
mkdir -p /home/nepi/.ssh
sudo chown nepi:nepi /home/nepi/.ssh
chmod 0700 /home/nepi/.ssh
sudo chown nepi:nepi /opt/nepi/config/home/nepi/ssh/authorized_keys
chmod 0600 /opt/nepi/config/home/nepi/ssh/authorized_keys
ln -sf /opt/nepi/config/home/nepi/ssh/authorized_keys /home/nepi/.ssh/authorized_keys
sudo chown nepi:nepi /home/nepi/.ssh/authorized_keys
chmod 0600 /home/nepi/.ssh/authorized_keys

# Disable apport to avoid crash reports on a display
sudo systemctl disable apport

# Now start installing stuff... first, update all base packages
sudo apt update
sudo apt upgrade

# Install and configure chrony
echo "Installing chrony for NTP services"
sudo apt install chrony
sudo mv /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak
sudo ln -sf /opt/nepi/config/etc/chrony/chrony.conf.num_factory /etc/chrony/chrony.conf

# Install and configure samba with default passwords
echo "Installing samba for network shared drives"
sudo apt install samba
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
sudo ln -sf /opt/nepi/config/etc/samba/smb.conf /etc/samba/smb.conf
printf "nepi\nnepi\n" | sudo smbpasswd -a nepi
# Create the unprivileged user account and samba credentials
sudo useradd nepi_user
printf "nepi_user\nnepi_user\n" | sudo passwd nepi_user
sudo usermod -a -G sambashare nepi_user
printf "nepi_user\nnepi_user\n" | sudo smbpasswd -a nepi_user

# Install Base Python Packages
echo "Installing base python packages"
sudo apt install python-pip
pip install --user -U pip
pip install --user virtualenv
sudo apt install libffi-dev # Required for python cryptography library

# NEPI runtime python dependencies. Must install these in system folders such that they are on root user's python path
sudo -H pip install onvif # Necessary for nepi_edge_sdk_onvif

sudo apt install scons # Required for num_gpsd
sudo apt install zstd # Required for Zed SDK installer

# Install Base Node.js Tools and Packages (Required for RUI, etc.)
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm install 8.11.1 # RUI-required Node version as of this script creation

# Create the mountpoint for samba shares (now that sambashare group exists)
sudo mkdir /mnt/nepi_storage
sudo chown :sambashare /mnt/nepi_storage

# Install ROS Melodic (-desktop, which includes important packages)
# This script should be useful even on non-Jetson (but ARM-based) systems,
# hence included here rather than in the Jetson-specific setup script.
mkdir tmp && cd tmp
git clone https://github.com/jetsonhacks/installROS.git
cd installROS
./installROS.sh -p ros-melodic-desktop
cd ../..
rm -rf ./tmp

# Clean up some unwanted .bashrc artifacts of the ROS install process
sed -i 's:source /opt/ros/melodic/setup.bash:\n\#Automatically sourcing setup.bash interferes with ROS1/ROS2 interops\n#source /opt/ros/melodic/setup.bash:g' /home/nepi/.bashrc
sed -i 's:export ROS_IP=:#export ROS_IP=:g' /home/nepi/.bashrc

ADDITIONAL_ROS_PACKAGES="python3-catkin-tools \
    ros-${ROS_VERSION}-rosbridge-server \
    ros-${ROS_VERSION}-pcl-ros \
    ros-${ROS_VERSION}-web-video-server \
    ros-${ROS_VERSION}-camera-info-manager \
    ros-${ROS_VERSION}-tf2-geometry-msgs"
    # Deprecated ROS packages?
    #ros-${ROS_VERSION}-tf-conversions
    #ros-${ROS_VERSION}-diagnostic-updater 
    #ros-${ROS_VERSION}-vision-msgs

sudo apt install $ADDITIONAL_ROS_PACKAGES

# Need to change the default .ros folder permissions for some reason
sudo mkdir /home/nepi/.ros
sudo chown -R nepi:nepi /home/nepi/.ros

# Install nepi-link dependencies
mkdir /opt/
sudo apt install socat protobuf-compiler python3-pip
pip3 install virtualenv

# Shut down NetworkManager... causes issues with NEPI IP addr. management
sudo systemctl disable NetworkManager

# Clean-up unnecessary installed s/w
sudo apt autoremove



