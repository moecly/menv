#!/bin/bash
set -e

# ============================================================
# LUKS Partition Password & Key Slot Manager
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================================
# Detect LUKS partitions
# ============================================================

detect_luks() {
    local devices
    devices=$(lsblk -lno NAME,FSTYPE 2>/dev/null | awk '$2=="crypto_LUKS" {print "/dev/"$1}' || true)

    if [[ -z "$devices" ]]; then
        echo -e "${RED}==> Error: No LUKS partitions found on this system.${NC}"
        exit 1
    fi

    echo "$devices"
}

select_device() {
    local devices=()
    mapfile -t devices < <(detect_luks)

    local filtered=()
    for d in "${devices[@]}"; do
        [[ -n "$d" ]] && filtered+=("$d")
    done
    devices=("${filtered[@]}")

    if [[ ${#devices[@]} -eq 0 ]]; then
        echo -e "${RED}==> Error: No valid LUKS devices found.${NC}" >&2
        exit 1
    fi

    if [[ ${#devices[@]} -eq 1 ]]; then
        echo -e "${GREEN}==> Detected LUKS device: ${devices[0]}${NC}" >&2
        echo "${devices[0]}"
        return
    fi

    echo -e "${BOLD}==> Multiple LUKS partitions detected:${NC}" >&2
    echo >&2
    for i in "${!devices[@]}"; do
        echo -e "  ${CYAN}$((i+1))${NC}  ${devices[$i]}" >&2
    done
    echo >&2

    while true; do
        read -rp "Select device number [1-${#devices[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#devices[@]} )); then
            echo "${devices[$((choice-1))]}"
            return
        fi
        echo -e "${RED}==> Invalid selection.${NC}" >&2
    done
}

# ============================================================
# Operations
# ============================================================

view_slots() {
    local device="$1"
    echo -e "${BOLD}==> Partition info for ${CYAN}${device}${NC}${BOLD}:${NC}"
    echo
    sudo cryptsetup luksDump "$device" 2>/dev/null
    echo
    echo -e "${CYAN}(Check the Keyslots: section for active password slots)${NC}"
}

change_password() {
    local device="$1"
    echo -e "${BOLD}==> Changing LUKS password for ${CYAN}${device}${NC}"
    echo
    sudo cryptsetup luksChangeKey "$device"
    echo -e "${GREEN}==> Password changed successfully!${NC}"
}

add_key() {
    local device="$1"
    echo -e "${BOLD}==> Adding new LUKS key for ${CYAN}${device}${NC}"
    echo
    sudo cryptsetup luksAddKey "$device"
    echo -e "${GREEN}==> New key added successfully!${NC}"
}

remove_key() {
    local device="$1"
    echo -e "${BOLD}==> Removing LUKS key for ${CYAN}${device}${NC}"
    echo

    view_slots "$device"
    echo

    read -rp "Enter key slot number to remove: " slot
    if [[ -z "$slot" || ! "$slot" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}==> Invalid slot number.${NC}"
        return 1
    fi

    echo -e "${YELLOW}==> Warning: This will permanently delete key slot $slot${NC}"
    read -rp "Are you sure? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}==> Aborted.${NC}"
        return
    fi

    sudo cryptsetup luksKillSlot "$device" "$slot"
    echo -e "${GREEN}==> Key slot $slot removed successfully!${NC}"
}

# ============================================================
# Main
# ============================================================

echo -e "${BOLD}==> LUKS Password & Key Slot Manager${NC}"
echo

# Determine device
if [[ -n "$1" ]]; then
    DEVICE="$1"
    if [[ ! -b "$DEVICE" ]]; then
        echo -e "${RED}==> Error: $DEVICE is not a valid block device.${NC}"
        exit 1
    fi
    if ! sudo cryptsetup isLuks "$DEVICE" 2>/dev/null; then
        echo -e "${RED}==> Error: $DEVICE is not a LUKS partition.${NC}"
        exit 1
    fi
    echo -e "${GREEN}==> Using specified device: ${DEVICE}${NC}"
else
    DEVICE=$(select_device)
fi

echo
echo -e "${BOLD}==> Device: ${CYAN}${DEVICE}${NC}${BOLD}${NC}"
echo

while true; do
    echo -e "${BOLD}==> Menu:${NC}"
    echo -e "  ${CYAN}1${NC}  View partition info (header)"
    echo -e "  ${CYAN}2${NC}  Change password"
    echo -e "  ${CYAN}3${NC}  Add password"
    echo -e "  ${CYAN}4${NC}  Remove password (by slot)"
    echo -e "  ${CYAN}5${NC}  Exit"
    echo

    read -rp "Select option [1-5]: " option
    echo

    case "$option" in
        1) view_slots "$DEVICE" ;;
        2) change_password "$DEVICE" ;;
        3) add_key "$DEVICE" ;;
        4) remove_key "$DEVICE" ;;
        5)
            echo -e "${GREEN}==> Done.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}==> Invalid option.${NC}"
            ;;
    esac

    echo
done
