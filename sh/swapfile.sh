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
SWAP_SUBVOL="/swap"
SWAPFILE="${SWAP_SUBVOL}/swapfile"
FSTAB_ENTRY="${SWAPFILE} none swap defaults 0 0"

echo "==> Creating ${SIZE_GB}GB swap file in dedicated subvolume..."

echo "==> 1/5 Deactivating old swap files..."
# 关闭所有 swap，处理可能的旧文件
sudo swapoff -a 2>/dev/null || true

# 删除旧的 /swapfile（如果存在）
if [ -f "/swapfile" ]; then
    echo "    Removing old /swapfile..."
    sudo rm -f /swapfile
fi

# 如果旧子卷存在，先删除
if sudo btrfs subvolume list / | grep -q "path ${SWAP_SUBVOL#/}$"; then
    echo "    Removing old swap subvolume..."
    sudo btrfs subvolume delete "$SWAP_SUBVOL"
fi

echo "==> 2/5 Creating dedicated @swap subvolume..."
sudo btrfs subvolume create "$SWAP_SUBVOL"

echo "==> 3/5 Creating ${SIZE_GB}GB swap file with Btrfs native method..."
sudo btrfs filesystem mkswapfile --size "${SIZE_GB}G" "$SWAPFILE"

echo "==> 4/5 Setting permissions..."
sudo chmod 600 "$SWAPFILE"

echo "==> 5/5 Enabling swap..."
sudo swapon "$SWAPFILE"

echo "==> Updating /etc/fstab..."
# 先移除旧的 swap 条目
sudo sed -i '/swapfile/d' /etc/fstab
# 添加新的
echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab

echo ""
echo "==> Done! Summary:"
echo "    Swap size: ${SIZE_GB}GB"
echo "    Location:  ${SWAPFILE}"
echo "    Subvolume: ${SWAP_SUBVOL}"
echo ""
echo "Current swap status:"
swapon --show
echo ""
echo "Subvolume layout:"
sudo btrfs subvolume list / | grep swap
