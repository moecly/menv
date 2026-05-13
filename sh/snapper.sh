#!/bin/bash
set -e

# ============================================================
# Snapper Configuration Script
# ============================================================

echo "==> Checking Btrfs root filesystem..."
if ! findmnt -no FSTYPE / | grep -q btrfs; then
    echo "==> Warning: Root filesystem is not Btrfs. Snapper requires Btrfs."
    read -rp "Continue anyway? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "==> Aborted."
        exit 1
    fi
fi

echo "==> Checking if snapper is installed..."
if ! command -v snapper &> /dev/null; then
    echo "==> Error: snapper is not installed."
    read -rp "Install snapper now? (y/N): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        sudo pacman -S --needed --noconfirm snapper
    else
        echo "==> Aborted."
        exit 1
    fi
fi

# Check if root config already exists
if [[ -f /etc/snapper/configs/root ]]; then
    echo "==> Snapper root config already exists, skipping creation."
else
    echo "==> Creating snapper root config..."
    sudo snapper -c root create-config /
fi

# Configure timeline frequency
echo "==> Configuring timeline frequency (hourly snapshots)..."
TIMELINE_CONF="/etc/snapper/configs/root"
if [[ -f "$TIMELINE_CONF" ]]; then
    sudo sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="10"/' "$TIMELINE_CONF"
    sudo sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' "$TIMELINE_CONF"
    sudo sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="4"/' "$TIMELINE_CONF"
    sudo sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="6"/' "$TIMELINE_CONF"
    sudo sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="3"/' "$TIMELINE_CONF"
    echo "==> Timeline limits: 10 hourly, 7 daily, 4 weekly, 6 monthly, 3 yearly"
fi

# Enable timers (check if unit files exist first)
echo "==> Enabling snapper timers..."
for timer in snapper-timeline.timer snapper-cleanup.timer; do
    if systemctl list-unit-files "$timer" &>/dev/null; then
        sudo systemctl enable --now "$timer"
        echo "  $timer enabled"
    else
        echo "  $timer not found, skipping"
    fi
done

# Get the snapper subvolume and fix .snapshots directory
SUBVOL=$(snapper -c root get-config | grep "^SUBVOLUME" | cut -d'=' -f2)
if [[ -z "$SUBVOL" ]]; then
    SUBVOL="/"
fi
echo "==> Snapper subvolume: $SUBVOL"

SNAP_DIR="${SUBVOL}.snapshots"

# Check if .snapshots is a proper btrfs subvolume
is_subvolume=false
if [[ -d "$SNAP_DIR" ]]; then
    if btrfs subvolume show "$SNAP_DIR" &>/dev/null; then
        is_subvolume=true
        echo "==> .snapshots subvolume already exists."
    else
        echo "==> WARNING: .snapshots exists but is NOT a btrfs subvolume!"
        echo "==> Snapper requires .snapshots to be a btrfs subvolume to function."
        read -rp "Convert it to a subvolume? This will move existing contents. (y/N): " fix_confirm
        if [[ "$fix_confirm" == "y" || "$fix_confirm" == "Y" ]]; then
            local tmp_dir="/tmp/.snapshots_backup_$$"
            sudo mv "$SNAP_DIR" "$tmp_dir"
            sudo btrfs subvolume create "$SNAP_DIR"
            sudo chmod 750 "$SNAP_DIR"
            sudo chown root:root "$SNAP_DIR"
            sudo rsync -a "$tmp_dir/" "$SNAP_DIR/" 2>/dev/null || true
            sudo rm -rf "$tmp_dir"
            is_subvolume=true
            echo "==> Converted .snapshots to btrfs subvolume."
        else
            echo "==> Skipping. Snapper may not work correctly."
            is_subvolume=true
        fi
    fi
fi

if [[ "$is_subvolume" = false ]]; then
    echo "==> Creating .snapshots subvolume..."
    sudo btrfs subvolume create "$SNAP_DIR"
    sudo chmod 750 "$SNAP_DIR"
    sudo chown root:root "$SNAP_DIR"
fi

# Create initial snapshot
echo "==> Creating initial snapshot..."
if sudo snapper -c root create --description "Initial snapshot"; then
    echo "==> Initial snapshot created successfully!"
else
    echo "==> Warning: Failed to create initial snapshot."
    echo "==> You may need to check your Btrfs subvolume setup."
fi

# Display status
echo
echo "==> Snapper configuration complete!"
echo "==> Current snapshots:"
sudo snapper -c root list 2>/dev/null || echo "(unable to list snapshots)"
