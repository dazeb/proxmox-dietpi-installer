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

# Import the qcow2 file to the specified storage
echo "Importing disk image to storage..."
qm importdisk "$ID" "$IMAGE_NAME" "$STORAGE"

# Retrieve the disk path for further usage and print for user
DISK_PATH=$(qm config "$ID" | awk '/unused0/{print $2;exit}')
if [[ $DISK_PATH ]]; then
    echo "Disk path: $DISK_PATH"
else
    echo "Error: Failed to import disk for VM $ID"
    exit 1
fi

# Set VM settings
qm set "$ID" --cores "$CORES"
qm set "$ID" --memory "$RAM"
qm set "$ID" --scsihw virtio-scsi-pci
qm set "$ID" --net0 'virtio,bridge=vmbr0'
qm set "$ID" --scsi0 "$DISK_PATH,discard=on,ssd=1"

# Verify if the disk was set correctly
if qm config "$ID" | grep -q "scsi0"; then
    qm set "$ID" --boot order='scsi0'
else
    echo "Error: Failed to set the disk for VM $ID"
    exit 1
fi

qm set "$ID" --name 'dietpi' >/dev/null

# Description with logo and horizontal links
DESCRIPTION='
<p align="center">
  <img src="https://i.ibb.co/rH7GPX5/dietpi.png" alt="DietPi Logo" width="40" />
  <br/>
  <strong>DietPi VM</strong>
  <br/>
  <a href="https://dietpi.com/">DietPi Website</a> &bull; 
  <a href="https://dietpi.com/docs/">DietPi Docs</a> &bull; 
  <a href="https://dietpi.com/forum/">DietPi Forum</a>
  <br/>
  <a href="https://dietpi.com/blog/">DietPi Blog</a>
</p>
'

qm set "$ID" --description "$DESCRIPTION" >/dev/null

# Tell user the virtual machine is created  
echo "VM $ID Created."

# Start the virtual machine
qm start "$ID"
