#!/bin/bash

# --- 1. Essential Tools ---
# CachyOS includes paru, but we'll add yay for your familiarity
echo "Adding yay for familiarity..."
sudo pacman -S --needed git base-devel --noconfirm
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git
    cd yay && makepkg -si --noconfirm
    cd .. && rm -rf yay
fi

# --- 2. Install KDE & Ly (Minimal) ---
# We grab the core plasma desktop and the Ly TUI greeter
echo "Installing Plasma Core and Ly..."
sudo pacman -S --noconfirm plasma-desktop dolphin konsole ly
sudo systemctl enable ly.service

# --- 3. VM Detection (Only if you're testing in a VM) ---
if hostnamectl status | grep -q "virtualization"; then
    echo "VM Detected! Forcing Wayland compatibility..."
    mkdir -p ~/.config/hypr
    echo "env = WLR_NO_HARDWARE_CURSORS,1" >> ~/.config/hypr/hyprland.conf
    echo "env = WLR_RENDERER_ALLOW_SOFTWARE,1" >> ~/.config/hypr/hyprland.conf
fi

# --- 4. Run the DMS Installer ---
# This is the "Magic" step that sets up Hyprland and the Material 3 UI.
echo "Launching Dank Material Shell Installer..."
curl -fsSL https://install.danklinux.com | sh

# --- 5. Fix TTY Conflicts ---
sudo systemctl disable getty@tty2.service 2>/dev/null

echo "Setup Complete! Type 'reboot' to start your new environment."
