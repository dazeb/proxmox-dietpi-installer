#!/bin/bash

# Variables
IMAGE_URL=$(whiptail --inputbox 'Enter the URL for the DietPi image (default: https://dietpi.com/downloads/images/DietPi_Proxmox-x86_64-Bookworm.qcow2.xz):' 8 78 'https://dietpi.com/downloads/images/DietPi_Proxmox-x86_64-Bookworm.qcow2.xz' --title 'DietPi Installation' 3>&1 1>&2 2>&3)
RAM=$(whiptail --inputbox 'Enter the amount of RAM (in MB) for the new virtual machine (default: 2048):' 8 78 2048 --title 'DietPi Installation' 3>&1 1>&2 2>&3)
CORES=$(whiptail --inputbox 'Enter the number of cores for the new virtual machine (default: 2):' 8 78 2 --title 'DietPi Installation' 3>&1 1>&2 2>&3)

# Install xz-utils if missing
dpkg-query -s xz-utils &> /dev/null || { echo 'Installing xz-utils for DietPi image decompression'; apt-get update; apt-get -y install xz-utils; }

# Get the next available VMID
ID=$(pvesh get /cluster/nextid)

touch "/etc/pve/qemu-server/$ID.conf"

# Get the storage name from the user
STORAGE=$(whiptail --inputbox 'Enter the storage name where the image should be imported:' 8 78 --title 'DietPi Installation' 3>&1 1>&2 2>&3)

# Download DietPi image
wget "$IMAGE_URL"

# Decompress the image
IMAGE_NAME=${IMAGE_URL##*/}
xz -d "$IMAGE_NAME"
IMAGE_NAME=${IMAGE_NAME%.xz}
sleep 3

# Import the qcow2 file to the default virtual machine storage
qm importdisk "$ID" "$IMAGE_NAME" "$STORAGE"

# Set vm settings
qm set "$ID" --cores "$CORES"
qm set "$ID" --memory "$RAM"
qm set "$ID" --scsihw virtio-scsi-pci
qm set "$ID" --net0 'virtio,bridge=vmbr0'
qm set "$ID" --scsi0 "$STORAGE:vm-$ID-disk-0,discard=on,ssd=1"
qm set "$ID" --boot order='scsi0'
qm set "$ID" --name 'dietpi' >/dev/null
qm set "$ID" --description '### [DietPi Website](https://dietpi.com/)
### [DietPi Docs](https://dietpi.com/docs/)  
### [DietPi Forum](https://dietpi.com/forum/)  
### [DietPi Blog](https://dietpi.com/blog/)' >/dev/null

# Tell user the virtual machine is created  
echo "VM $ID Created."

# Start the virtual machine
qm start "$ID"
