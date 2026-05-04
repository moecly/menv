#!/bin/bash

# Enable Btrfs quota support
echo "Enabling Btrfs quota..."
sudo btrfs quota enable /

# Display current quota group information
echo "Current Btrfs qgroup info:"
sudo btrfs qgroup show /

# Optional: Set subvolume quota (example: limit @home subvolume to 50GB)
# sudo btrfs qgroup limit 50G /home

echo "Btrfs quota enabled and verified."

