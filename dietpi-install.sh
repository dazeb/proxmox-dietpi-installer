#!/bin/bash

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    # Remove any downloaded files
    rm -f DietPi_*
    # Remove any temporary files
    rm -f /tmp/dietpi_*
    echo "Cleanup complete. Exiting."
    exit 1
}

# Trap Ctrl+C and other interrupts
trap cleanup INT TERM

# Select DietPi OS Version
while true; do
    OS_VERSION=$(whiptail --title 'DietPi Installation' --menu 'Select DietPi image:' 19 65 11 \
        ''                '───────── Debian 13 Trixie ─────────' \
        'trixie'          'Standard (Recommended)' \
        'trixie-uefi'     'UEFI Boot' \
        ''                '───────── Debian 12 Bookworm ───────' \
        'bookworm'        'Standard' \
        'bookworm-uefi'   'UEFI Boot' \
        ''                '───────── Debian 14 Forky ──────────' \
        'forky'           'Standard (Testing)' \
        'forky-uefi'      'UEFI Boot (Testing)' \
        ''                '────────────────────────────────────' \
        'custom'          'Custom URL' 3>&1 1>&2 2>&3)

    # Check if user cancelled
    if [ $? -ne 0 ]; then
        cleanup
    fi

    # If separator selected, show menu again
    if [ -n "$OS_VERSION" ]; then
        break
    fi
done

# Set IMAGE_URL based on selection
BASE_URL="https://dietpi.com/downloads/images"
case $OS_VERSION in
    trixie)
        IMAGE_URL="$BASE_URL/DietPi_Proxmox-x86_64-Trixie.qcow2.xz"
        ;;
    trixie-uefi)
        IMAGE_URL="$BASE_URL/DietPi_Proxmox-UEFI-x86_64-Trixie.qcow2.xz"
        ;;
    bookworm)
        IMAGE_URL="$BASE_URL/DietPi_Proxmox-x86_64-Bookworm.qcow2.xz"
        ;;
    bookworm-uefi)
        IMAGE_URL="$BASE_URL/DietPi_Proxmox-UEFI-x86_64-Bookworm.qcow2.xz"
        ;;
    forky)
        IMAGE_URL="$BASE_URL/DietPi_Proxmox-x86_64-Forky.qcow2.xz"
        ;;
    forky-uefi)
        IMAGE_URL="$BASE_URL/DietPi_Proxmox-UEFI-x86_64-Forky.qcow2.xz"
        ;;
    custom)
        IMAGE_URL=$(whiptail --inputbox 'Enter the URL for the DietPi image:' 8 78 "$BASE_URL/DietPi_Proxmox-x86_64-Trixie.qcow2.xz" --title 'DietPi Installation' 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            cleanup
        fi
        ;;
    *)
        echo "Invalid selection"
        cleanup
        ;;
esac

RAM=$(whiptail --inputbox 'Enter the amount of RAM (in MB) for the new virtual machine (default: 2048):' 8 78 2048 --title 'DietPi Installation' 3>&1 1>&2 2>&3)

# Check if user cancelled
if [ $? -ne 0 ]; then
    cleanup
fi

CORES=$(whiptail --inputbox 'Enter the number of cores for the new virtual machine (default: 2):' 8 78 2 --title 'DietPi Installation' 3>&1 1>&2 2>&3)

# Check if user cancelled
if [ $? -ne 0 ]; then
    cleanup
fi

# Install xz-utils if missing
dpkg-query -s xz-utils &> /dev/null || { echo 'Installing xz-utils for DietPi image decompression'; apt-get update; apt-get -y install xz-utils; }

# Get the next available VMID
ID=$(pvesh get /cluster/nextid)

# Create VM config file
if ! touch "/etc/pve/qemu-server/$ID.conf"; then
    echo "Error: Could not create VM configuration file"
    cleanup
fi

# Get the storage name from the user
STORAGE=$(whiptail --inputbox 'Enter the storage name where the image should be imported:' 8 78 --title 'DietPi Installation' 3>&1 1>&2 2>&3)

# Check if user cancelled or if storage is empty
if [ $? -ne 0 ] || [ -z "$STORAGE" ]; then
    echo "Storage selection cancelled or empty. Aborting."
    cleanup
fi

# Create temporary directory for downloads
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || cleanup

# Download DietPi image
if ! wget "$IMAGE_URL"; then
    echo "Error: Failed to download image"
    cleanup
fi

# Decompress the image
IMAGE_NAME=${IMAGE_URL##*/}
if ! xz -d "$IMAGE_NAME"; then
    echo "Error: Failed to decompress image"
    cleanup
fi

IMAGE_NAME=${IMAGE_NAME%.xz}

# Import the qcow2 file to the specified storage
echo "Importing disk image to storage..."
if ! qm importdisk "$ID" "$IMAGE_NAME" "$STORAGE"; then
    echo "Error: Failed to import disk"
    cleanup
fi

# Retrieve the disk path
DISK_PATH=$(qm config "$ID" | awk '/unused0/{print $2;exit}')
if [[ ! $DISK_PATH ]]; then
    echo "Error: Failed to get disk path"
    cleanup
fi

echo "Disk path: $DISK_PATH"

# Set VM settings
qm set "$ID" --cores "$CORES" || cleanup
qm set "$ID" --memory "$RAM" || cleanup
qm set "$ID" --scsihw virtio-scsi-pci || cleanup
qm set "$ID" --net0 'virtio,bridge=vmbr0' || cleanup
qm set "$ID" --scsi0 "$DISK_PATH,discard=on,ssd=1" || cleanup
qm set "$ID" --ostype l26 || cleanup

# Verify disk setup and set boot order
if qm config "$ID" | grep -q "scsi0"; then
    qm set "$ID" --boot order='scsi0'
else
    echo "Error: Failed to set the disk for VM $ID"
    cleanup
fi

# Set VM name
qm set "$ID" --name 'dietpi' >/dev/null

# Set description
DESCRIPTION='
<p align="center">
<img src="https://dietpi.com/images/dietpi-logo_128x128.png" alt="DietPi Logo" width="40">
<br>
<strong>DietPi VM</strong>
<br>
<a href="https://dietpi.com/">Website</a> &bull; 
<a href="https://dietpi.com/docs/">Documentation</a> &bull; 
<a href="https://dietpi.com/forum/">Forum</a>
<br>
<a href="https://dietpi.com/blog/">Blog</a> &bull; 
<a href="https://github.com/MichaIng/DietPi">GitHub</a>
</p>
'

qm set "$ID" --description "$DESCRIPTION" >/dev/null

# Clean up temporary files
cd - || cleanup
rm -rf "$TEMP_DIR"

echo "VM $ID Created successfully."

# Start the virtual machine
qm start "$ID"
