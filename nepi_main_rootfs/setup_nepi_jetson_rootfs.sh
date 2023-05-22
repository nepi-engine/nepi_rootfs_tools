#!/bin/bash

# Jetson-specific NEPI rootfs setup steps. This is a specialization of the base NEPI rootfs
# and calls that parent script as a pre-step.

# Run the parent script first
sudo ./setup_nepi_rootfs.sh

# Install Jetpack SDK stuff
# Have to uncomment entries in /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
sudo sed -i 's/\#deb/deb/g' /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
sudo apt update
sudo apt install nvidia-jetpack

# Work-around opencv path installation issue on Jetson (after jetpack installation)
sudo ln -s /usr/include/opencv4/opencv2/ /usr/include/opencv
sudo ln -s /usr/lib/aarch64-linux-gnu/cmake/opencv4 /usr/share/OpenCV

# Clean up anything that jetpack puts on the Desktop
rm /home/nepi/Desktop/*

# Install Zed SDK 3.8 (for Jetpack 4.6.2 - update wget command below for other versions)
# TODO: Maybe this should be optional with user prompt -- it is quite a large install and takes a long time.
mkdir tmp && cd tmp
wget https://download.stereolabs.com/zedsdk/3.8/l4t32.7/jetsons
chmod a+x jetsons
yes Y | ./jetsons # Accept all defaults. TODO: Maybe should let the user do it interactively?
cd ..
rm -rf ./tmp