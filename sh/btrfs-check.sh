#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ISSUES=0

check_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

check_warn() {
    echo -e "  ${YELLOW}!${NC} $1"
    ISSUES=$((ISSUES + 1))
}

check_err() {
    echo -e "  ${RED}✗${NC} $1"
    ISSUES=$((ISSUES + 1))
}

echo -e "${BOLD}==> Btrfs Filesystem Health Check${NC}"
echo

# ============================================================
# 1. Mount Points & Parameters
# ============================================================

echo -e "${CYAN}>> Mount Points & Parameters${NC}"
echo

MOUNTS_DATA=$(mktemp)
mount | grep "type btrfs" | awk '{print $1, $3, $6}' | sort -u > "$MOUNTS_DATA"

while IFS= read -r line; do
    [ -z "$line" ] && continue
    device=$(echo "$line" | awk '{print $1}')
    mp=$(echo "$line" | awk '{print $2}')
    opts=$(echo "$line" | sed 's/.*(\(.*\))/\1/' | tr ',' '\n')

    echo -e "  ${BOLD}$mp${NC} ($device)"

    # Check each parameter
    if echo "$opts" | grep -q "noatime"; then
        check_ok "noatime enabled"
    else
        check_warn "noatime not set"
    fi

    if echo "$opts" | grep -q "compress=zstd"; then
        level=$(echo "$opts" | grep -o 'compress=zstd:[0-9]*' | cut -d: -f2)
        if [ "$level" -ge 1 ] && [ "$level" -le 3 ]; then
            check_ok "compress=zstd:$level (optimal)"
        else
            check_warn "compress=zstd:$level (recommend 1-3)"
        fi
    else
        check_warn "compression not enabled"
    fi

    if echo "$opts" | grep -q "^ssd$\|,ssd,"; then
        check_ok "ssd mode enabled"
    else
        check_warn "ssd mode not detected"
    fi

    if echo "$opts" | grep -q "discard=async"; then
        check_ok "discard=async enabled"
    elif echo "$opts" | grep -q "discard"; then
        check_warn "discard enabled but not async"
    else
        check_warn "discard not enabled"
    fi

    if echo "$opts" | grep -q "space_cache=v2"; then
        check_ok "space_cache=v2 enabled"
    else
        check_warn "space_cache=v2 not set"
    fi

    if echo "$opts" | grep -q "commit="; then
        commit_val=$(echo "$opts" | grep -o 'commit=[0-9]*' | cut -d= -f2)
        check_ok "commit=$commit_val (explicit)"
    else
        check_ok "commit=30 (default, not explicitly set)"
    fi

    echo
done < "$MOUNTS_DATA"
rm -f "$MOUNTS_DATA"

# ============================================================
# 2. Read-Only Status
# ============================================================

echo -e "${CYAN}>> Read-Only Check${NC}"
echo

ro_mounts=$(mount | grep btrfs | grep -w "ro," || true)
if [ -z "$ro_mounts" ]; then
    check_ok "All Btrfs filesystems mounted read-write"
else
    check_err "Read-only mounts detected:"
    echo "$ro_mounts" | awk '{print "    " $3}'
fi
echo

# ============================================================
# 3. Kernel Errors
# ============================================================

echo -e "${CYAN}>> Kernel Error Log${NC}"
echo

errors=$(dmesg 2>/dev/null | grep -i btrfs | grep -iE "error|corrupt|readonly" | tail -5 || true)
if [ -z "$errors" ]; then
    check_ok "No Btrfs errors in kernel log"
else
    check_warn "Recent Btrfs errors found:"
    echo "$errors" | sed 's/^/    /'
fi
echo

# ============================================================
# 4. Disk Usage
# ============================================================

echo -e "${CYAN}>> Disk Usage${NC}"
echo

if command -v btrfs &>/dev/null; then
    sudo btrfs filesystem df -h / 2>/dev/null | while IFS= read -r line; do
        echo "  $line"
    done
    echo
else
    check_warn "btrfs-progs not installed"
    echo
fi

# ============================================================
# 5. Device Status
# ============================================================

echo -e "${CYAN}>> Device Status${NC}"
echo

if command -v btrfs &>/dev/null; then
    dev_output=$(sudo btrfs filesystem show / 2>/dev/null)
    if echo "$dev_output" | grep -q "MISSING"; then
        check_err "Missing devices detected"
        echo "$dev_output" | grep MISSING | sed 's/^/    /'
    else
        check_ok "All devices online"
    fi
    echo
else
    check_warn "btrfs-progs not installed"
    echo
fi

# ============================================================
# 6. Scrub Status
# ============================================================

echo -e "${CYAN}>> Scrub Status${NC}"
echo

if command -v btrfs &>/dev/null; then
    scrub=$(sudo btrfs scrub status / 2>/dev/null)
    if echo "$scrub" | grep -qi "no active scrub\|no scrub"; then
        if echo "$scrub" | grep -qi "never ran\|not yet"; then
            check_warn "Scrub has never been run"
        else
            check_warn "Scrub status unknown"
        fi
    elif echo "$scrub" | grep -qi "status.*running\|status.*running for\|status.*interrupted"; then
        check_warn "Scrub currently running"
    elif echo "$scrub" | grep -qi "status.*finished"; then
        if echo "$scrub" | grep -qi "no errors found"; then
            start_time=$(echo "$scrub" | grep "Scrub started:" | sed 's/.*:   //')
            duration=$(echo "$scrub" | grep "Duration:" | sed 's/.*:   //')
            check_ok "Last scrub: $start_time (duration: $duration, no errors)"
        else
            error_summary=$(echo "$scrub" | grep "Error summary:" | sed 's/.*:   //')
            check_warn "Last scrub completed with issues: $error_summary"
        fi
    elif echo "$scrub" | grep -qi "status.*canceled"; then
        check_warn "Last scrub was canceled"
    else
        check_warn "Unable to parse scrub status"
    fi
    echo
else
    check_warn "btrfs-progs not installed"
    echo
fi

# ============================================================
# 7. Service Status
# ============================================================

echo -e "${CYAN}>> Btrfs Maintenance Services${NC}"
echo

for svc in btrfs-trim.timer btrfs-scrub.timer btrfs-balance.timer; do
    if systemctl list-unit-files "$svc" 2>/dev/null | grep -q "$svc"; then
        if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
            active=$(systemctl is-active "$svc" 2>/dev/null)
            if [[ "$active" == "active" || "$active" == "waiting" ]]; then
                check_ok "$svc (enabled, $active)"
            else
                check_warn "$svc (enabled, inactive)"
            fi
        else
            check_warn "$svc (not enabled)"
        fi
    else
        check_warn "$svc (not found)"
    fi
done
echo

# ============================================================
# Summary
# ============================================================

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}==> All checks passed!${NC}"
else
    echo -e "${YELLOW}==> Found $ISSUES issue(s). Review warnings above.${NC}"
fi
