#!/bin/bash
set -e

# Check if systemd-boot is available
if ! command -v bootctl &> /dev/null; then
    echo "==> Error: bootctl not found. Is systemd-boot installed?"
    exit 1
fi

# Find all boot entries
ENTRIES=()
TITLES=()
FILES=()

for entry in /boot/loader/entries/*.conf; do
    [ -f "$entry" ] || continue
    filename=$(basename "$entry")
    title=$(grep -m1 "^title" "$entry" | sed 's/^title *//')
    [ -z "$title" ] && title="$filename"

    ENTRIES+=("$filename")
    TITLES+=("$title")
    FILES+=("$entry")
done

if [ ${#ENTRIES[@]} -eq 0 ]; then
    echo "==> Error: No boot entries found in /boot/loader/entries/"
    exit 1
fi

# Display available entries
echo "==> Available boot entries:"
for i in "${!TITLES[@]}"; do
    idx=$((i + 1))
    echo "  $idx) ${TITLES[$i]} (${ENTRIES[$i]})"
done
echo

# Get current default entry
current=$(bootctl get-default 2>/dev/null || echo "unknown")
echo "==> Current default: $current"
echo

# Prompt user for selection
read -rp "Select default entry (1-${#ENTRIES[@]}): " choice

# Validate input
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#ENTRIES[@]}" ]; then
    echo "==> Error: Invalid selection."
    exit 1
fi

idx=$((choice - 1))
selected="${ENTRIES[$idx]}"

# Set the default entry
bootctl set-default "$selected"
echo "==> Default boot entry set to: $selected"
