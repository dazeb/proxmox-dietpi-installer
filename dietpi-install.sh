#!/bin/bash

# Variables
IMAGE_URL=$(whiptail --backtitle "Proxmox DietPi VM Installer" --inputbox 'Enter the URL for the DietPi image (default: https://dietpi.com/downloads/images/DietPi_Proxmox-x86_64-Bullseye.7z):' 8 78 'https://dietpi.com/downloads/images/DietPi_Proxmox-x86_64-Bullseye.7z' --title 'DietPi Installation' 3>&1 1>&2 2>&3)
RAM=$(whiptail --backtitle "Proxmox DietPi VM Installer" --inputbox 'Enter the amount of RAM (in MB) for the new virtual machine (default: 2048):' 8 78 2048 --title 'DietPi Installation' 3>&1 1>&2 2>&3)
CORES=$(whiptail --backtitle "Proxmox DietPi VM Installer" --inputbox 'Enter the number of cores for the new virtual machine (default: 2):' 8 78 2 --title 'DietPi Installation' 3>&1 1>&2 2>&3)

# Install p7zip if missing
dpkg-query -s p7zip &> /dev/null || { echo 'Installing p7zip for DietPi archive extraction'; apt-get update; apt-get -y install p7zip; }

# Get the next available VMID
ID=$(pvesh get /cluster/nextid)

touch "/etc/pve/qemu-server/$ID.conf"

# Variables for whiptail dialog
declare -a STORAGE_MENU=()

# Read disk stats line by line  
DISK_STATS=$(pvesm status -content images)
# Create a temporary file to store the disk stats
DISK_STATS_FILE=$(mktemp)
echo "$DISK_STATS" > "$DISK_STATS_FILE"

# Validate and select storage
MSG_MAX_LENGTH=0

# Read storage info and format it
while read -r line; do
  TAG=$(echo $line | awk '{print $1}')
  TYPE=$(echo $line | awk '{print $2}')
  FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format "%.2f")
  #FREE="Free: $(printf "%9sB" "$FREE")"
  ITEM="  Type: $TYPE  $FREE"
  STORAGE_MENU+=("$TAG" "$ITEM" "OFF") 
done < <(pvesm status -content images | grep -P '^\w')

# Display menu with formatted storage information and increased width
STORAGE=$(whiptail --backtitle "Proxmox DietPi VM Installer" --title "Storage Pools" --radiolist \
  "Which storage pool would you like to use for the new virtual machine?\nTo make a selection, use the Spacebar.\n\n$DISK_STATS" \
  20 100 6 \
  "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit

# Get the type of the selected storage
STORAGE_TYPE=$(pvesm status | grep "^$STORAGE " | awk '{print $2}')

# Determine the disk parameter based on the storage type
if [[ "$STORAGE_TYPE" == "dir" ]]; then
  qm_disk_param="$STORAGE:$ID/vm-$ID-disk-0.raw"
else
  qm_disk_param="$STORAGE:vm-$ID-disk-0"
fi


# Download DietPi image
wget "$IMAGE_URL"

# Extract the image
IMAGE_NAME=${IMAGE_URL##*/}
IMAGE_NAME=${IMAGE_NAME%.7z}
7zr e "$IMAGE_NAME.7z" "$IMAGE_NAME.qcow2"
sleep 3

# import the qcow2 file to the default virtual machine storage
qm importdisk "$ID" "$IMAGE_NAME.qcow2" "$STORAGE"

# Set vm settings
qm set "$ID" --cores "$CORES"
qm set "$ID" --memory "$RAM"
qm set "$ID" --net0 "virtio,bridge=vmbr0"
qm set "$ID" --scsi0 "$qm_disk_param"
qm set "$ID" --scsihw virtio-scsi-pci
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

# Cleanup temp files
rm "$DISK_STATS_FILE"
rm "$IMAGE_NAME.7z"
echo "Temporary files cleaned"
