#!/bin/bash
set -e

# ============================================================
# System Service Enable Script
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SERVICES=(
    "system:keyd.service:键盘重映射服务"
    "user:dms.service:动态菜单服务"
    "system:ufw.service:防火墙服务"
    "system:tuned.service:系统调优服务"
    "system:sshd.service:SSH 服务器"
    "system:NetworkManager.service:网络管理器"
    "system:systemd-timesyncd.service:时间同步服务"
    "system:snapper-timeline.timer:Snapper 定时快照"
    "system:snapper-cleanup.timer:Snapper 定期清理"
    "system:fstrim.timer:文件系统 TRIM 定时任务"
    "system:btrfs-scrub.timer:Btrfs 数据校验定时任务"
    "system:btrfs-balance.timer:Btrfs 空间平衡定时任务"
    "system:udisks2.service:磁盘管理 (udisks2)"
    "system:tailscaled.service:VPN 内网穿透服务"
    "user:syncthing.service:文件同步服务"
)

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
