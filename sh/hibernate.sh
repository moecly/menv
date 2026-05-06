#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SWAPFILE="/swap/swapfile"
MKINITCPIO_DROPIN="/etc/mkinitcpio.conf.d/resume.conf"
CMDLINE_FILE="/etc/kernel/cmdline"

issues=()
fixes=()

echo -e "${CYAN}==> Checking prerequisites...${NC}"
echo

if ! command -v bootctl &> /dev/null; then
    echo -e "  ${RED}✗${NC} bootctl not found. Is systemd-boot installed?"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} systemd-boot detected"

if [ ! -f "$SWAPFILE" ]; then
    echo -e "  ${RED}✗${NC} Swapfile not found at $SWAPFILE"
    echo "    Create one first with: menv run swapfile <size_GB>"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Swapfile found: $SWAPFILE"

swap_size=$(du -h "$SWAPFILE" | cut -f1)
echo "    Size: $swap_size"

echo
echo -e "${CYAN}==> Detecting resume parameters...${NC}"
echo

device=$(findmnt -n -o SOURCE --target "$SWAPFILE" 2>/dev/null)

if [ -z "$device" ]; then
    device=$(df "$SWAPFILE" | tail -1 | awk '{print $1}')
fi

# Strip Btrfs subvolume path (e.g., /dev/mapper/root[/@] -> /dev/mapper/root)
device=$(echo "$device" | sed 's/\[.*\]//')

echo "  Swap device: $device"

UUID=$(lsblk -no UUID "$device" 2>/dev/null)

if [ -n "$UUID" ]; then
    echo -e "  ${GREEN}✓${NC} UUID=$UUID"
else
    echo -e "  ${RED}✗${NC} Could not detect partition identifier"
    exit 1
fi

# Get swapfile offset using btrfs inspect-internal (correct for Btrfs)
OFFSET=$(sudo btrfs inspect-internal map-swapfile -r "$SWAPFILE" 2>/dev/null)

if [ -z "$OFFSET" ]; then
    echo -e "  ${RED}✗${NC} Could not determine swapfile offset"
    echo "    Make sure the swapfile is on a Btrfs filesystem"
    echo "    Try running: sudo btrfs inspect-internal map-swapfile -r $SWAPFILE"
    exit 1
fi

echo -e "  ${GREEN}✓${NC} resume_offset=$OFFSET"
echo

RESUME_PARAM="resume=UUID=$UUID"
OFFSET_PARAM="resume_offset=$OFFSET"

echo -e "${CYAN}==> Checking mkinitcpio configuration...${NC}"
echo

hook_exists=false
if [ -f "$MKINITCPIO_DROPIN" ] && grep -q "resume" "$MKINITCPIO_DROPIN" 2>/dev/null; then
    hook_exists=true
elif grep -q "HOOKS=.*resume" /etc/mkinitcpio.conf 2>/dev/null; then
    hook_exists=true
fi

if $hook_exists; then
    echo -e "  ${GREEN}✓${NC} resume hook already configured"
else
    echo -e "  ${RED}✗${NC} resume hook NOT found"
    issues+=("missing_resume_hook")
    fixes+=("Add resume hook to $MKINITCPIO_DROPIN")
fi

if [ ! -d "/etc/mkinitcpio.conf.d" ]; then
    echo -e "  ${YELLOW}!${NC} /etc/mkinitcpio.conf.d does not exist (will be created)"
else
    echo -e "  ${GREEN}✓${NC} /etc/mkinitcpio.conf.d exists"
fi

preset_ok=true
for preset in /etc/mkinitcpio.d/*.preset; do
    if [ -f "$preset" ]; then
        if grep -q "^ALL_config=" "$preset" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} $(basename "$preset") has uncommented ALL_config (drop-in disabled)"
            preset_ok=false
        fi
    fi
done
$preset_ok && echo -e "  ${GREEN}✓${NC} All presets support drop-in configuration"

echo

echo -e "${CYAN}==> Checking kernel command line...${NC}"
echo

if [ ! -f "$CMDLINE_FILE" ]; then
    echo -e "  ${RED}✗${NC} $CMDLINE_FILE not found"
    exit 1
fi

current_cmdline=$(cat "$CMDLINE_FILE")
echo "  Current: $current_cmdline"
echo

if echo "$current_cmdline" | grep -q "resume=UUID="; then
    echo -e "  ${GREEN}✓${NC} resume parameter already present"
    current_resume=$(echo "$current_cmdline" | grep -o "resume=[^ ]*")
    echo "    Current: $current_resume"
else
    echo -e "  ${RED}✗${NC} resume parameter NOT found"
    issues+=("missing_resume_cmdline")
    fixes+=("Add '$RESUME_PARAM' to $CMDLINE_FILE")
fi

if echo "$current_cmdline" | grep -q "resume_offset="; then
    current_offset=$(echo "$current_cmdline" | grep -o "resume_offset=[^ ]*")
    expected_offset="resume_offset=$OFFSET"
    if [ "$current_offset" != "$expected_offset" ]; then
        echo -e "  ${RED}✗${NC} resume_offset mismatch"
        echo "    Current:  $current_offset"
        echo "    Expected: $expected_offset"
        issues+=("wrong_offset_cmdline")
        fixes+=("Update offset from '$current_offset' to '$expected_offset'")
    else
        echo -e "  ${GREEN}✓${NC} resume_offset parameter correct"
    fi
else
    echo -e "  ${RED}✗${NC} resume_offset parameter NOT found"
    issues+=("missing_offset_cmdline")
    fixes+=("Add '$OFFSET_PARAM' to $CMDLINE_FILE")
fi

echo

if [ ${#issues[@]} -eq 0 ]; then
    echo -e "${GREEN}==> Hibernation is already configured correctly!${NC}"
    exit 0
fi

echo -e "${CYAN}==> Summary${NC}"
echo "  Issues found: ${#issues[@]}"
for issue in "${issues[@]}"; do
    echo "    - $issue"
done
echo
echo "  Planned fixes:"
for fix in "${fixes[@]}"; do
    echo "    - $fix"
done
echo

read -rp "Proceed with fixes? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo

if [[ " ${issues[*]} " =~ "missing_resume_hook" ]]; then
    echo -e "${CYAN}==> Creating $MKINITCPIO_DROPIN...${NC}"
    sudo mkdir -p /etc/mkinitcpio.conf.d
    echo 'HOOKS+=(resume)' | sudo tee "$MKINITCPIO_DROPIN"
    echo
fi

if [[ " ${issues[*]} " =~ "missing_resume_cmdline" ]] || [[ " ${issues[*]} " =~ "missing_offset_cmdline" ]] || [[ " ${issues[*]} " =~ "wrong_offset_cmdline" ]]; then
    echo -e "${CYAN}==> Updating $CMDLINE_FILE...${NC}"

    sudo cp "$CMDLINE_FILE" "${CMDLINE_FILE}.bak"
    echo "  Backup created: ${CMDLINE_FILE}.bak"

    if [[ " ${issues[*]} " =~ "wrong_offset_cmdline" ]]; then
        sudo sed -i "s/resume_offset=[0-9]*/resume_offset=$OFFSET/" "$CMDLINE_FILE"
        echo "  Updated: resume_offset=$OFFSET"
    else
        new_params=""
        if [[ " ${issues[*]} " =~ "missing_resume_cmdline" ]]; then
            new_params="$RESUME_PARAM"
        fi
        if [[ " ${issues[*]} " =~ "missing_offset_cmdline" ]]; then
            [ -n "$new_params" ] && new_params="$new_params "
            new_params="${new_params}${OFFSET_PARAM}"
        fi

        sudo sed -i "s/$/ ${new_params}/" "$CMDLINE_FILE"
        echo "  Added: $new_params"
    fi
    echo "  New cmdline: $(cat "$CMDLINE_FILE")"
    echo
fi

echo -e "${CYAN}==> Regenerating initramfs...${NC}"
echo "  This may take a moment..."
sudo mkinitcpio -P
echo

echo -e "${CYAN}==> Regenerating boot entries...${NC}"
sudo kernel-install add-all
echo

echo -e "${GREEN}==> Hibernation configuration complete!${NC}"
echo
echo "  Parameters configured:"
echo "    $RESUME_PARAM"
echo "    $OFFSET_PARAM"
echo
echo "  To test hibernation:"
echo "    systemctl hibernate"
echo
echo -e "${YELLOW}NOTE: Make sure your swap size is >= RAM size for hibernation to work.${NC}"
