#!/bin/bash

# --- 1. System Optimization ---
THREADS=$(nproc)
sudo sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$THREADS\"/" /etc/makepkg.conf

# --- 2. Essential Tools & Yay ---
sudo pacman -S --needed base-devel git --noconfirm
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si --noconfirm
cd .. && rm -rf yay

# --- 3. Install KDE & Ly ---
sudo pacman -S --noconfirm plasma-desktop dolphin konsole ly
sudo systemctl enable ly.service

# --- 4. VM Specific Tweaks (CRITICAL FOR HYPRLAND) ---
# We check if we are in a VM and set the necessary environment variables
if hostnamectl status | grep -q "virtualization"; then
    echo "VM Detected! Applying Wayland compatibility tweaks..."
    mkdir -p ~/.config/hypr
    cat <<EOF >> ~/.config/hypr/hyprland.conf
#  VM Compatibility
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_RENDERER_ALLOW_SOFTWARE,1
EOF
fi

# --- 5. Launch DMS Installer ---
curl -fsSL https://install.danklinux.com | sh

sudo systemctl disable getty@tty2.service 2>/dev/null
echo "Setup Complete! If in a VM, ensure 3D Acceleration is ENABLED in settings."
