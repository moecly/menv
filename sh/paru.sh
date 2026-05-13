#!/bin/bash
set -e

# Check if paru is already installed
if command -v paru &> /dev/null; then
    echo "==> paru is already installed"
    exit 0
fi

# Install dependencies
echo "==> 1/4 Installing base-devel and git..."
sudo pacman -S --needed --noconfirm base-devel git

# Clone paru repo
PARU_DIR="/tmp/paru"
if [ -d "$PARU_DIR" ]; then
    rm -rf "$PARU_DIR"
fi

echo "==> 2/4 Cloning paru repository..."
git clone https://aur.archlinux.org/paru.git "$PARU_DIR"

# Build and install
echo "==> 3/4 Building and installing paru..."
(cd "$PARU_DIR" && makepkg -si --noconfirm)

# Clean up
echo "==> 4/4 Cleaning up..."
rm -rf "$PARU_DIR"

echo "==> paru installed successfully!"
