#!/bin/bash

# Variables
IMAGE_URL='https://dietpi.com/downloads/images/DietPi_Proxmox-x86_64-Bullseye.7z'
RAM=2048
CORES=2
VMNAME='DietPi'
# Get a list of storage to display as a selection list
storageList=$(pvesm status)
# Get the next available VMID
ID=$(pvesh get /cluster/nextid)
UUID=$(cat /proc/sys/kernel/random/uuid)

# Initialize an empty array for the list of storage options
storageListArray=()

# Loop through each line of the storage list
while read -r -a columns; do
    # Assign each column to a variable
    pveName=${columns[0]}
    pveType=${columns[1]}
    pveStatus=${columns[2]}
    pveTotal=${columns[3]}
    pveUsed=${columns[4]}
    pveAvailable=${columns[5]}
    pvePercentUsed=${columns[6]}

    # Generate a list into a new array (skipping the title line)
    if [ $pveName != 'Name' ]; then
      storageListArray+=( "$pveName" "$pvePercentUsed Storage Used" OFF)
    fi
done <<< "$storageList"

# Prompt for download URL
IMAGE_URL=$(whiptail --inputbox 'Enter the URL for the DietPi image (default: https://dietpi.com/downloads/images/DietPi_Proxmox-x86_64-Bullseye.7z):' 8 78 $IMAGE_URL --title 'DietPi Installation' 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
  whiptail --title 'Cancelled' --msgbox 'Cancelling process' 8 78
  exit
fi

# Prompt for amount of RAM
RAM=$(whiptail --inputbox 'Enter the amount of RAM (in MB) for the new virtual machine (default: 2048):' 8 78 $RAM --title 'DietPi Installation' 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
  whiptail --title 'Cancelled' --msgbox 'Cancelling process' 8 78
  exit
fi

# Prompt for core count
CORES=$(whiptail --inputbox 'Enter the number of cores for the new virtual machine (default: 2):' 8 78 $CORES --title 'DietPi Installation' 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
  whiptail --title 'Cancelled' --msgbox 'Cancelling process' 8 78
  exit
fi

# Prompt for VMID (pre-populate with next ID available)
ID=$(whiptail --inputbox 'Enter the VMID you wish to use:' 8 78 $ID --title 'DietPi Installation' 3>&1 1>&2 2>&3)
if [ $exitstatus != 0 ]; then
  whiptail --title 'Cancelled' --msgbox 'Cancelling process' 8 78
  exit
fi

# Prompt to select the storage to use from a radio list
STORAGE=$(whiptail --title 'DietPi Installation' --radiolist --separate-output \
'Select the storage name where the image should be imported:' 20 78 4 \
"${storageListArray[@]}" 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
  whiptail --title 'Cancelled' --msgbox 'Cancelling process' 8 78
  exit
fi

$ Prompt for the display name of the VM
VMNAME=$(whiptail --inputbox 'Enter the Display Name you wish to use:' 8 78 $VMNAME --title 'DietPi Installation' 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus != 0 ]; then
  whiptail --title 'Cancelled' --msgbox 'Cancelling process' 8 78
  exit
fi

touch "/etc/pve/qemu-server/$ID.conf"

# Download DietPi image
wget "$IMAGE_URL"

# Extract the image (overwrite output file if it already exists)
IMAGE_NAME=${IMAGE_URL##*/}
IMAGE_NAME=${IMAGE_NAME%.7z}
7zr e -y "$IMAGE_NAME.7z" "$IMAGE_NAME.qcow2"
sleep 3

# import the qcow2 file to the default virtual machine storage
qm importdisk "$ID" "$IMAGE_NAME.qcow2" "$STORAGE"

# Set vm settings
qm set "$ID" --cores "$CORES"
qm set "$ID" --memory "$RAM"
qm set "$ID" --net0 'virtio,bridge=vmbr0'
qm set "$ID" --scsi0 "$STORAGE:vm-$ID-disk-0"
qm set "$ID" --boot order='scsi0'
qm set "$ID" --scsihw virtio-scsi-single
qm set "$ID" --machine q35
qm set "$ID" --ostype l26
qm set "$ID" --name "$VMNAME"
qm set "$ID" --smbios1 uuid="$UUID"

# Tell user the virtual machine is created
echo "VM $ID Created."

# Start the virtual machine
qm start "$ID"
