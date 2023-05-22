#!/bin/bash

# S2X-specific NEPI rootfs setup steps. This is a specialization of the NEPI Jetson rootfs
# and calls that parent script as a pre-step.

# Run the parent script first
sudo ./setup_nepi_jetson_rootfs.sh

# The script is assumed to run from a directory structure that mirrors the Git repo it is housed in.
HOME_DIR=$PWD

# Copy the S2X-specialized Linux config files
sudo cp -r ${HOME_DIR}/config_s2x/* /opt/nepi/config

# Link S2X fstab (mounts SSD partition 3 as nepi_storage)
sudo mv /etc/fstab /etc/fstab.bak
sudo ln -sf /opt/nepi/config/etc/fstab /etc/fstab

# And mount it to ensure that expected nepi_storage folders exist
sudo mount /mnt/nepi_storage
sudo mkdir -p /mnt/nepi_storage/data
sudo mkdir -p /mnt/nepi_storage/ai_models
sudo mkdir -p /mnt/nepi_storage/automation_scripts
sudo mkdir -p /mnt/nepi_storage/logs
# For S2X, the software update/archive folders are in nepi_storage, too... but that is not always the case (e.g., updated from USB)
sudo mkdir -p /mnt/nepi_storage/nepi_full_img
sudo mkdir -p /mnt/nepi_storage/nepi_full_img_archive
# Set ownership and permissions properly - Awkardly, samba seems to use a mixed bag of samba and system authentication, but the following works
sudo chown -R nepi:sambashare /mnt/nepi_storage/*
sudo chmod -R 0775 /mnt/nepi_storage/*

