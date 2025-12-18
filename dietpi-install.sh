#!/bin/bash

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    # Remove any downloaded files
    rm -f DietPi_*
    # Remove any verification files
    rm -f *.sha256 *.asc dietpi.gpg
    # Remove any temporary files
    rm -f /tmp/dietpi_*
    echo "Cleanup complete. Exiting."
    exit 1
}

# Trap Ctrl+C and other interrupts
trap cleanup INT TERM

# Verify SHA256 checksum
verify_sha256() {
    local image_file="$1"
    local checksum_url="$2"

    echo "Downloading SHA256 checksum..."
    if ! wget -q "$checksum_url" -O "${image_file}.sha256"; then
        echo "Warning: Could not download checksum file from $checksum_url"
        return 1
    fi

    echo "Verifying SHA256 checksum..."
    if ! sha256sum -c "${image_file}.sha256" 2>/dev/null | grep -q "OK"; then
        echo "ERROR: SHA256 checksum verification FAILED!"
        echo "The downloaded file may be corrupted or tampered with."
        return 1
    fi

    echo "✓ SHA256 checksum verified successfully"
    return 0
}

# Import DietPi GPG public key (optional - won't fail if import unsuccessful)
import_dietpi_gpg_key() {
    # Check if GPG is available
    if ! command -v gpg &> /dev/null; then
        return 1
    fi

    # DietPi GPG key details
    local key_id="C2C4D1DEF7C96C6EDF3937B2536B2A4A2E72D870"
    local key_url="https://github.com/MichaIng.gpg"

    # Check if key is already imported
    if gpg --list-keys "$key_id" &>/dev/null; then
        echo "✓ DietPi GPG key already imported"
        return 0
    fi

    echo "Importing DietPi GPG public key..."

    # Try to download and import key from GitHub
    if wget -q "$key_url" -O dietpi.gpg && gpg --import dietpi.gpg >/dev/null; then
        rm -f dietpi.gpg
        echo "✓ DietPi GPG key imported successfully"
        return 0
    else
        rm -f dietpi.gpg
        echo "Note: Could not import DietPi GPG key"
        return 1
    fi
}

# Verify GPG signature (optional - won't fail if GPG unavailable)
verify_gpg_signature() {
    local image_file="$1"
    local signature_url="$2"

    # Check if GPG is available
    if ! command -v gpg &> /dev/null; then
        echo "GPG not found, skipping signature verification"
        return 0
    fi

    # Try to import DietPi GPG key
    import_dietpi_gpg_key

    echo "Downloading GPG signature..."
    if ! wget -q "$signature_url" -O "${image_file}.asc"; then
        echo "Warning: Could not download signature file, skipping GPG verification"
        return 0
    fi

    echo "Verifying GPG signature..."
    # Verify signature
    if gpg --verify "${image_file}.asc" "$image_file" &>/dev/null; then
        echo "✓ GPG signature verified successfully"
    else
        echo "Note: GPG signature could not be verified"
        echo "      This is optional - continuing with SHA256 verification only"
    fi

    return 0
}

# Prompt user to retry download on verification failure
retry_download_prompt() {
    if whiptail --title "Verification Failed" --yesno "Download verification failed. Would you like to retry the download?" 10 60 3>&1 1>&2 2>&3; then
        return 0  # User wants to retry
    else
        return 1  # User wants to abort
    fi
}

# Main verification function
verify_download() {
    local image_file="$1"
    local image_url="$2"

    # Construct checksum and signature URLs
    local checksum_url="${image_url}.sha256"
    local signature_url="${image_url}.asc"

    echo ""
    echo "=== Verifying Download Integrity ==="

    # SHA256 verification (mandatory)
    if ! verify_sha256 "$image_file" "$checksum_url"; then
        return 1
    fi

    # GPG signature verification (optional)
    verify_gpg_signature "$image_file" "$signature_url"

    echo "=== Verification Complete ==="
    echo ""
    return 0
}

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

# Flag to track if we should verify download (only for official images)
VERIFY_DOWNLOAD="true"
if [ "$OS_VERSION" = "custom" ]; then
    VERIFY_DOWNLOAD="false"
fi

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

# Download DietPi image with verification
DOWNLOAD_SUCCESS=false
while [ "$DOWNLOAD_SUCCESS" = "false" ]; do
    # Download the image
    echo "Downloading DietPi image..."
    if ! wget "$IMAGE_URL"; then
        echo "Error: Failed to download image"
        if ! retry_download_prompt; then
            cleanup
        fi
        continue
    fi

    # Extract filename
    IMAGE_NAME=${IMAGE_URL##*/}

    # Verify download if this is an official image
    if [ "$VERIFY_DOWNLOAD" = "true" ]; then
        if ! verify_download "$IMAGE_NAME" "$IMAGE_URL"; then
            # Verification failed - ask user to retry
            if retry_download_prompt; then
                echo "Retrying download..."
                rm -f "$IMAGE_NAME" "${IMAGE_NAME}.sha256" "${IMAGE_NAME}.asc"
                continue
            else
                echo "Verification failed and user chose to abort"
                cleanup
            fi
        fi
    else
        echo "Skipping verification for custom URL (user assumes risk)"
    fi

    DOWNLOAD_SUCCESS=true
done

# Decompress the image
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
