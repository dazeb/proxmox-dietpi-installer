#!/bin/bash

# Variables
IMAGE_URL=$(whiptail --inputbox "Enter the URL for the DietPi image (default: https://dietpi.com/downloads/images/DietPi_Proxmox-x86_64-Bullseye.7>
RAM=1024
CORES=2

# Get the next available VMID
ID=$(pvesh get /cluster/nextid)

touch /etc/pve/qemu-server/$ID.conf

# Get the storage name from the user
STORAGE=$(whiptail --inputbox "Enter the storage name where the image should be imported:" 8 78 --title "DietPi Installation" 3>&1 1>&2 2>&3)

# Create the virtual machine

# Download DietPi image
wget $IMAGE_URL

# Extract the image
7zr x DietPi_Proxmox-x86_64-Bullseye.7z
sleep 3

# import the qcow2 file to the default virtual machine storage
qm importdisk $ID DietPi_Proxmox-x86_64-Bullseye.qcow2 $STORAGE

# qm create $ID --memory $RAM --net0 "virtio,bridge=vmbr0" --cores $CORES --scsi0 $STORAGE:vm-$ID-disk-0 --name dietpi

# set vm storage
qm set $ID --net0 "virtio,bridge=vmbr0"
qm set $ID --scsi0 "$STORAGE:vm-$ID-disk-0"
qm set $ID --boot order='scsi0'
qm set $ID --scsihw virtio-scsi-pci
# Create the virtual machine

# Start the virtual machine
echo "VM $ID Created"
