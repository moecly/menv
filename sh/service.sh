#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

MENV_DIR="$(dirname "$SCRIPT_DIR")"
source "$MENV_DIR/config.conf"

echo -e "${BOLD}==> Enabling system services...${NC}"
echo

for entry in "${SERVICES[@]}"; do
    IFS=: read -r svc_type svc_name svc_desc <<< "$entry"

    # Check if service exists
    if [[ "$svc_type" == "system" ]]; then
        if ! systemctl list-unit-files "$svc_name" &>/dev/null; then
            echo -e "  ${YELLOW}⊝${NC} ${CYAN}$svc_name${NC} ($svc_desc) - ${YELLOW}unit not found${NC}"
            continue
        fi

        if systemctl is-enabled "$svc_name" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} ${CYAN}$svc_name${NC} ($svc_desc) - ${GREEN}already enabled${NC}"
            continue
        fi

        echo -ne "  ${GREEN}+${NC} ${CYAN}$svc_name${NC} ($svc_desc) - enabling... "
        if sudo systemctl enable --now "$svc_name" 2>/dev/null; then
            echo -e "${GREEN}done${NC}"
        else
            echo -e "${RED}failed${NC}"
        fi
    elif [[ "$svc_type" == "user" ]]; then
        if ! systemctl --user list-unit-files "$svc_name" &>/dev/null; then
            echo -e "  ${YELLOW}⊝${NC} ${CYAN}$svc_name${NC} ($svc_desc) - ${YELLOW}unit not found${NC}"
            continue
        fi

        if systemctl --user is-enabled "$svc_name" &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} ${CYAN}$svc_name${NC} ($svc_desc) - ${GREEN}already enabled${NC}"
            continue
        fi

        echo -ne "  ${GREEN}+${NC} ${CYAN}$svc_name${NC} ($svc_desc) - enabling... "
        if systemctl --user enable --now "$svc_name" 2>/dev/null; then
            echo -e "${GREEN}done${NC}"
        else
            echo -e "${RED}failed${NC}"
        fi
    fi
done

echo
echo -e "${BOLD}==> Service configuration complete!${NC}"
