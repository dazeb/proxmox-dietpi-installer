
![proxmox-dietpi](https://user-images.githubusercontent.com/67932890/213890139-61bd9c23-4ed2-49f2-a627-0b303d0a4f8f.png)

# Proxmox DietPi Installer

A Proxmox Helper Script to install DietPi in Proxmox 7 & 8.

## How to use

### Oneline installer directly from GitHub
```sh
bash <(curl -sSfL https://raw.githubusercontent.com/dazeb/proxmox-dietpi-installer/main/dietpi-install.sh)
```

### Download the script to your Proxmox host by cloning the repo or using `wget`

```sh
git clone https://github.com/dazeb/proxmox-dietpi-installer.git
```

cd into the folder, make the file executable then run the script
```sh
cd proxmox-dietpi-installer
chmod +x dietpi-install.sh
./dietpi-install.sh
```
### You can also download the script with `wget`
```sh
wget https://raw.githubusercontent.com/dazeb/proxmox-dietpi-installer/main/dietpi-install.sh
```
Make the file executable then run the script.
```sh
chmod +x dietpi-install.sh
./dietpi-install.sh
```

The installer will ask where to import the VM disk, How much RAM to allocate and the number of processor cores. The rest is automatic.
Default values are 2GB RAM and 2 Cores.

#### Tested and confirmed working with Proxmox 7.x & 8.x

### For more helper scripts like this but much better check out [tteck's Proxmox Heler Scripts](https://tteck.github.io/Proxmox/)
