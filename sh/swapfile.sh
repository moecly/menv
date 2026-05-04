#!/bin/bash
set -e

# Usage: ./create_swap.sh 24
# Argument: desired swap size in GB

if [ -z "$1" ]; then
    echo "Error: Please specify swap size in GB"
    echo "Usage: $0 <size_GB>"
    echo "Example: $0 24"
    exit 1
fi

SIZE_GB="$1"
SIZE_MB=$((SIZE_GB * 1024))
SWAPFILE="/swapfile"

echo "==> Creating ${SIZE_GB}GB (${SIZE_MB}MB) swap file..."

echo "==> 1/5 Deactivating old swap file..."
sudo swapoff "$SWAPFILE" 2>/dev/null || true

if [ -f "$SWAPFILE" ]; then
    echo "==> Removing old file..."
    sudo rm -f "$SWAPFILE"
fi

echo "==> 2/5 Creating new file and disabling CoW..."
sudo touch "$SWAPFILE"
sudo chattr +C "$SWAPFILE"

echo "==> 3/5 Writing ${SIZE_GB}GB of data (may take a few minutes)..."
sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SIZE_MB" status=progress

echo "==> 4/5 Setting permissions and formatting..."
sudo chmod 600 "$SWAPFILE"
sudo mkswap "$SWAPFILE"

echo "==> 5/5 Enabling swap..."
sudo swapon "$SWAPFILE"

echo "==> Done! Current swap status:"
swapon --show
