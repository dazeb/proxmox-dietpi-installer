
![proxmox-dietpi](https://user-images.githubusercontent.com/67932890/213890139-61bd9c23-4ed2-49f2-a627-0b303d0a4f8f.png)

# Proxmox DietPi Installer

A Proxmox Helper Script to install DietPi in Proxmox 8 and 9.

## Requirements

- Proxmox VE 8.x or 9.x
- Root access to the Proxmox host (run from the console or an SSH session)
- At least one storage with the **VM images** content type enabled (local-lvm, a dir storage, or ZFS all work)
- Outbound internet access to `dietpi.com` and `github.com` (image, checksum and signature downloads)

## How to Use

There are two ways to install a DietPi VM: the one-liner, or a downloaded copy of the script.
All commands should be run in the Proxmox shell as root.

---

### One-liner Installer

Run the following command to install DietPi VM directly from GitHub:

```sh
bash <(curl -sSfL https://raw.githubusercontent.com/dazeb/proxmox-dietpi-installer/main/dietpi-install.sh)
```

---

### Download the Script

Clone the repo or fetch the script with `wget`, make it executable, then run it:

```sh
git clone https://github.com/dazeb/proxmox-dietpi-installer.git
cd proxmox-dietpi-installer
chmod +x dietpi-install.sh
./dietpi-install.sh
```

```sh
wget https://raw.githubusercontent.com/dazeb/proxmox-dietpi-installer/main/dietpi-install.sh
chmod +x dietpi-install.sh
./dietpi-install.sh
```

---

## Features

- **BIOS and UEFI installs** — pick the matching DietPi image. UEFI (OVMF) is mainly needed for PCIe/GPU passthrough or Secure Boot; UEFI VMs get q35, OVMF and an EFI disk with pre-enrolled keys
- **Integrity-checked downloads** — official images are verified against a SHA-256 checksum and a GPG signature from the pinned DietPi signing key before anything is created
- **Cleanup on cancel or failure** — cancelling at any prompt, or a failed download or import, removes the half-made VM and its temp files; Ctrl+C and SIGTERM do the same
- **Retry without duplicates** — a failed download can be retried on the same filename, so no `file.1` leftovers build up
- **Sensible defaults** — the VM matches the Proxmox web UI defaults, including the `x86-64-v2-AES` CPU model (plain `qm create` would silently hand out kvm64)
- **Custom image URLs** — bring your own image (verification is skipped for custom URLs)

## Installation Prompts

The installer will ask for the following information:

- **DietPi image** — Debian 13 Trixie, Debian 12 Bookworm or Debian 14 Forky (testing), each in a Standard or UEFI Boot variant, plus a Custom URL option
- **RAM** to allocate (default 2048 MB)
- **CPU cores** (default 2)
- **Storage** — pick from the host's image-capable storages

For custom URLs the installer also asks whether the image is UEFI (it guesses from the URL, so this is usually just a confirm).

You can cancel at any prompt — the installer exits cleanly and leaves nothing behind.

---

## What the Script Does

1. **Prompts** for the DietPi image, RAM, cores and target storage
2. **Installs `xz-utils`** if it is not already installed
3. **Downloads the image** to a temporary directory (with a retry prompt if the download fails)
4. **Verifies the download** — SHA-256 checksum and GPG signature checked against the pinned DietPi signing key (official images only)
5. **Decompresses the image**
6. **Creates the VM** — a fresh VMID is picked, and the VM is only created after the image is verified, so an aborted run leaves nothing behind
7. **Imports the disk** and attaches it as `scsi0` with discard and SSD optimisations
8. **Configures the VM** — `x86-64-v2-AES` CPU model, RAM, cores and a virtio network device; UEFI images also get the q35 machine type, OVMF and an EFI disk with pre-enrolled Secure Boot keys
9. **Sets metadata** — VM name and a description linking back to DietPi
10. **Starts the VM**

---

## First Boot

Open the VM console once the installer finishes and complete DietPi's initial setup. The default login is `root` / `dietpi` (change it during setup). After first-run is done you can shut down and adjust resources — cores, RAM, and so on — as needed.

---

## GPU / PCIe Passthrough

For PCIe/GPU passthrough, install with the UEFI image and switch the VM to the host CPU model after creation:

```sh
qm set <VMID> --cpu host
```

The installer creates the VM with the web UI's default CPU model (`x86-64-v2-AES`) so the switch is clean. Passthrough itself needs host-side IOMMU/VFIO setup, which this installer does not configure.

---

## Compatibility

Tested and confirmed working with Proxmox 8.x and 9.x, for both BIOS and UEFI installs.

---

## Developers

Developed by Darren Bennett & MichaIng, with contributions from mews-se (download verification, cleanup rework, CPU defaults).

---

## More Helper Scripts

For more helper scripts like this, check out the [Proxmox VE Helper-Scripts](https://community-scripts.github.io/ProxmoxVE/)
