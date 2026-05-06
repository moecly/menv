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
    echo "==> No boot entries found, attempting to regenerate..."

    # 检查 kernel-install 是否可用
    if ! command -v kernel-install &> /dev/null; then
        echo "==> Error: kernel-install not found. Unable to regenerate entries."
        exit 1
    fi

    # 重新生成所有已安装内核的启动项
    echo "==> Running: sudo kernel-install add-all"
    if ! sudo kernel-install add-all; then
        echo "==> Error: kernel-install add-all failed"
        exit 1
    fi

    # 重新扫描启动项
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

    # 验证修复结果
    if [ ${#ENTRIES[@]} -eq 0 ]; then
        echo "==> Error: No boot entries found after regeneration attempt."
        exit 1
    fi
    echo "==> Successfully regenerated boot entries."
fi

# Display available entries
echo "==> Available boot entries:"
for i in "${!TITLES[@]}"; do
    idx=$((i + 1))
    echo "  $idx) ${TITLES[$i]} (${ENTRIES[$i]})"
done
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
sudo bootctl set-default "$selected"
echo "==> Default boot entry set to: $selected"
