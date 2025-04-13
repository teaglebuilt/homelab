#! /bin/bash

set -e

# Get the PCI address for NVIDIA graphics card
PCI_ADDRESS=$(lspci | grep -i vga | grep -i nvidia | awk '{print $1}')


check_link_speed() {
  lspci -vvv | grep -i "LnkSta"
}

test_link_speed() {
  local speed=$1
  echo "⚡ Forcing GPU max link speed at ${speed}GT"
  echo $speed | sudo tee /sys/bus/pci/devices/$PCI_ADDRESS/max_link_speed
  echo "🔗 Checking current link speed:"
  check_link_speed
}

echo "🔍 Testing GPU link speed connection to Proxmox node host machine"

# Force link speed tests
test_link_speed 8  # Thunderbolt 3 Speed
test_link_speed 16 # Thunderbolt 4 Speed
