#!/bin/bash

# Function to display error messages
function error_exit {
    echo "$1" >&2
    exit 1
}

# Prompt the user for the destination directory
read -p "Enter the destination directory (e.g., /dev/sde): " DEST_DIR

# Check if the destination directory exists
if [ ! -b "$DEST_DIR" ]; then
    error_exit "Error: Destination directory $DEST_DIR does not exist or is not a block device."
fi

# Download the netboot.xyz ISO
ISO_URL="https://boot.netboot.xyz/ipxe/netboot.xyz.iso"
ISO_FILE="netboot.xyz.iso"

echo "Downloading netboot.xyz ISO..."
wget -O $ISO_FILE $ISO_URL || error_exit "Error: Failed to download the ISO file."

# Write the ISO image to the specified destination directory
echo "Writing the ISO image to $DEST_DIR..."
sudo dd if=$ISO_FILE of=$DEST_DIR bs=4M status=progress || error_exit "Error: Failed to write the ISO to $DEST_DIR."
sudo sync

# Clean up the ISO file
rm -f $ISO_FILE

echo "netboot.xyz ISO has been successfully written to $DEST_DIR."

# Parse endpoints from endpoints.yml
ENDPOINTS_FILE="src/endpoints.yml"
if [ ! -f "$ENDPOINTS_FILE" ]; then
    error_exit "Error: $ENDPOINTS_FILE not found."
fi

ENDPOINTS=$(grep -oP 'http.*' "$ENDPOINTS_FILE")

# Read each endpoint into variables
while IFS= read -r line; do
  case $line in
    *systemrescue*)
      SYSTEMRESCUE_ENDPOINT="$line"
      ;;
    *grml*)
      GRML_ENDPOINT="$line"
      ;;
    *kodachi*)
      KODACHI_ENDPOINT="$line"
      ;;
    *windows*)
      WINDOWS_ENDPOINT="$line"
      ;;
  esac
done <<< "$ENDPOINTS"

# Create the custom iPXE script
IPXE_SCRIPT="custom.ipxe"

cat << EOF > $IPXE_SCRIPT
#!ipxe

# Error Handling Section
:boot_fail
echo Boot failed, returning to menu...
sleep 3
goto main_menu

# Network Configuration Section
:net_config
echo Configuring Network...
# ... add network configuration commands here ...
goto main_menu

# Main menu
:main_menu
menu Custom netboot.xyz Menu
item --gap --                   System Recovery Options:
item systemrescue              Load SystemRescue...
item grml                      Load GRML...
item kodachi                   Load Kodachi...
item --gap --                   Disk Management:
item gparted                   Load GParted...
item clonezilla                Load Clonezilla...
item --gap --                   Data Recovery:
item testdisk                  Load TestDisk...
item photorec                  Load PhotoRec...
item --gap --                   Network Troubleshooting:
item net_config                Network Configuration...
item --gap --                   System Diagnostics:
item memtest                   Load Memtest86+...
item --gap --                   Operating Systems:
item windows                   Load Windows
item --gap --                   Additional Options:
item exit                      Back to Main Menu
choose --default systemrescue --timeout 5000 option || goto exit
goto \${option}

# Boot Sections for each OS/Utility
:systemrescue
kernel ${SYSTEMRESCUE_ENDPOINT}/vmlinuz
initrd ${SYSTEMRESCUE_ENDPOINT}/initrd.img
imgargs vmlinuz setkmap=us
boot || goto boot_fail

:grml
kernel ${GRML_ENDPOINT}/vmlinuz
initrd ${GRML_ENDPOINT}/initrd.img
imgargs vmlinuz boot=live
boot || goto boot_fail

:kodachi
kernel ${KODACHI_ENDPOINT}/vmlinuz
initrd ${KODACHI_ENDPOINT}/initrd.img
imgargs vmlinuz boot=live noconfig=sudo username=kodachi hostname=kodachi
boot || goto boot_fail

:gparted
echo Booting into GParted...
kernel http://boot.netboot.xyz/ipxe/gparted/vmlinuz
initrd http://boot.netboot.xyz/ipxe/gparted/initrd.img
imgargs vmlinuz boot=live
boot || goto boot_fail

:clonezilla
echo Booting into Clonezilla...
kernel http://boot.netboot.xyz/ipxe/clonezilla/vmlinuz
initrd http://boot.netboot.xyz/ipxe/clonezilla/initrd.img
imgargs vmlinuz boot=live
boot || goto boot_fail

:testdisk
echo Booting into TestDisk...
kernel http://boot.netboot.xyz/ipxe/testdisk/vmlinuz
initrd http://boot.netboot.xyz/ipxe/testdisk/initrd.img
imgargs vmlinuz boot=live
boot || goto boot_fail

:photorec
echo Booting into PhotoRec...
kernel http://boot.netboot.xyz/ipxe/photorec/vmlinuz
initrd http://boot.netboot.xyz/ipxe/photorec/initrd.img
imgargs vmlinuz boot=live
boot || goto boot_fail

:memtest
echo Booting into Memtest86+...
kernel http://boot.netboot.xyz/ipxe/memdisk
initrd http://boot.netboot.xyz/ipxe/memtest86
imgargs memdisk
boot || goto boot_fail

:windows
echo "Booting into Windows..."
initrd ${WINDOWS_ENDPOINT}/boot.wim
chain ${WINDOWS_ENDPOINT}/boot.wim || goto boot_fail

:exit
chain http://boot.netboot.xyz
exit
EOF

echo "Custom iPXE script has been created as $IPXE_SCRIPT."
