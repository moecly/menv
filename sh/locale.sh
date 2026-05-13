#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

LOCALE_GEN="/etc/locale.gen"
LANGUAGES=(
    "en_US.UTF-8:English:en_US.UTF-8 UTF-8"
    "zh_CN.UTF-8:中文:zh_CN.UTF-8 UTF-8"
)

echo -e "${BOLD}==> Current Locale${NC}"
echo
current=$(localectl | grep "System Locale" | sed 's/.*LANG=//')
echo -e "  ${CYAN}$current${NC}"
echo

need_gen=false
for entry in "${LANGUAGES[@]}"; do
    IFS=: read -r locale label pattern <<< "$entry"
    if ! grep -q "^${pattern}$" "$LOCALE_GEN" 2>/dev/null; then
        echo -e "  ${YELLOW}+${NC} Enabling $locale ($label)..."
        sudo sed -i "s/^#\(${pattern}\)/\1/" "$LOCALE_GEN"
        need_gen=true
    fi
done

if $need_gen; then
    echo
    echo -e "${CYAN}==> Generating locales...${NC}"
    sudo locale-gen
    echo
else
    echo -e "  ${GREEN}✓${NC} All locales already enabled"
    echo
fi

echo -e "${BOLD}==> Available Languages${NC}"
echo
options=()
idx=0
for entry in "${LANGUAGES[@]}"; do
    IFS=: read -r locale label _pattern <<< "$entry"
    idx=$((idx + 1))
    options+=("$locale")
    if [[ "$locale" == "$current" ]]; then
        echo -e "  ${GREEN}$idx) $label ($locale)${NC} [current]"
    else
        echo -e "  $idx) $label ($locale)"
    fi
done
echo

if [[ ${#options[@]} -le 1 ]]; then
    echo -e "${YELLOW}Only one language available.${NC}"
    exit 0
fi

read -rp "Select target language (1-${#options[@]}): " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#options[@]}" ]; then
    echo -e "${RED}Error: Invalid selection.${NC}"
    exit 1
fi

target_locale="${options[$((choice - 1))]}"
if [[ "$target_locale" == "$current" ]]; then
    echo -e "${YELLOW}Already using $target_locale. No change needed.${NC}"
    exit 0
fi

echo
echo -e "${CYAN}==> Switching from ($current) to ($target_locale)...${NC}"
sudo localectl set-locale "LANG=$target_locale"
echo
echo -e "${GREEN}==> Locale updated!${NC}"
echo "  New: LANG=$target_locale"
echo
echo "  To apply:"
echo "    - Log out and log back in"
echo "    - Or restart running applications"
