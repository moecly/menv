#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CMDLINE_FILE="/etc/kernel/cmdline"

echo -e "${CYAN}==> Checking SSD TRIM support...${NC}"
echo

DISC_GRAN=$(lsblk -d -o DISC-GRAN --noheadings 2>/dev/null | grep -v ' 0B' | head -1)

if [ -z "$DISC_GRAN" ]; then
    echo -e "  ${RED}✗${NC} No TRIM support detected on any drive"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} TRIM supported (DISC-GRAN=$DISC_GRAN)"
echo

echo -e "${CYAN}==> Checking LUKS allow-discards...${NC}"
echo

current_cmdline=$(cat "$CMDLINE_FILE")

cryptdev=$(echo "$current_cmdline" | grep -o 'cryptdevice=[^ ]*')
if echo "$cryptdev" | grep -q 'allow-discards'; then
    echo -e "  ${GREEN}✓${NC} allow-discards already enabled in cryptdevice"
    echo
    echo -e "${GREEN}==> TRIM is already fully configured!${NC}"
    exit 0
fi

echo -e "  ${RED}✗${NC} allow-discards NOT found in cryptdevice parameter"
echo
echo "  Current: $cryptdev"
echo

echo -e "${CYAN}==> Planned fix:${NC}"
echo "  Add ':allow-discards' to cryptdevice parameter in $CMDLINE_FILE"
echo

read -rp "Proceed? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo
echo -e "${CYAN}==> Updating $CMDLINE_FILE...${NC}"

sudo cp "$CMDLINE_FILE" "${CMDLINE_FILE}.bak"
echo "  Backup created: ${CMDLINE_FILE}.bak"

sudo sed -i 's/cryptdevice=\(PARTUUID=[^:]*:[^ ]*\)/cryptdevice=\1:allow-discards/' "$CMDLINE_FILE"

echo "  New cmdline: $(cat "$CMDLINE_FILE")"
echo

echo -e "${CYAN}==> Regenerating initramfs...${NC}"
sudo mkinitcpio -P
echo

echo -e "${CYAN}==> Regenerating boot entries...${NC}"
sudo kernel-install add-all
echo

echo -e "${GREEN}==> TRIM configuration complete!${NC}"
echo
echo "  Next steps:"
echo "    1. Reboot your system"
echo "    2. Verify: lsblk -d -o DISC-GRAN"
echo "    3. Enable btrfs-trim.timer: menv run service"
echo
echo -e "${YELLOW}NOTE: TRIM requires both allow-discards AND btrfs-trim.timer to work.${NC}"
