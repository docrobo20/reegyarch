#!/bin/bash

# --- 1. System Optimization ---
THREADS=$(nproc)
sudo sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$THREADS\"/" /etc/makepkg.conf

# --- 2. Bootstrap Core Tools ---
sudo pacman -S --noconfirm git zsh base-devel

# --- 3. Personal Repo Setup (Reegylinux) ---
echo "Cloning reegylinux repository..."
git clone https://github.com/docobo20/reegylinux.git ~/reegylinux

# --- 4. Call the Modular Applications Script ---
if [ -f "$HOME/reegylinux/apps.sh" ]; then
    chmod +x ~/reegylinux/apps.sh
    ~/reegylinux/apps.sh
fi

# --- 5. Config Folder Imports (Symlinks) ---
mkdir -p ~/.config
[ -d "$HOME/reegylinux/mpv" ] && ln -sfn ~/reegylinux/mpv ~/.config/mpv
[ -d "$HOME/reegylinux/fastfetch" ] && ln -sfn ~/reegylinux/fastfetch ~/.config/fastfetch

# --- 6. Oh My Zsh & Yay Installation ---
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay

# --- 7. Hardened Zsh Configuration ---
echo "Forcing Zsh as the system shell..."

# 1. Ensure Zsh is installed (Safety check for vanilla Arch installs)
if ! command -v zsh &> /dev/null; then
    sudo pacman -S --noconfirm zsh
fi

# 2. Add to whitelist - Essential for Ly/KDE to allow the login
ZSH_BIN=$(which zsh)
if ! grep -q "$ZSH_BIN" /etc/shells; then
    echo "Registering $ZSH_BIN in /etc/shells..."
    echo "$ZSH_BIN" | sudo tee -a /etc/shells
fi

# 3. Deploy .zshrc BEFORE switching
# This prevents the 'New User' config function from triggering on first launch
rm -f "$HOME/.zshrc"
if [ -f "$HOME/reegylinux/.zshrc" ]; then
    ln -sf "$HOME/reegylinux/.zshrc" "$HOME/.zshrc"
    echo "Symlinked .zshrc from reegylinux."
else
    echo "Error: .zshrc missing from repo. Creating placeholder to prevent config prompt."
    touch "$HOME/.zshrc"
fi

# 4. Final Shell Switch
# We use the absolute path to ensure the login manager doesn't get confused
sudo chsh -s "$ZSH_BIN" $USER
echo "System shell set to $ZSH_BIN."

# --- 8. Desktop & Greeter ---
sudo pacman -S --noconfirm plasma-desktop dolphin konsole ly
sudo systemctl disable getty@tty2.service
sudo systemctl enable ly@tty2.service
sudo systemctl set-default graphical.target

# --- 9. DMS Installer & Isolation ---
curl -fsSL https://install.danklinux.com | sh
systemctl --user disable --now dms 2>/dev/null

# Migrate Envs to Hyprland
DMS_ENV="$HOME/.config/environment.d/90-dms.conf"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
if [ -f "$DMS_ENV" ]; then
    echo "" >> "$HYPR_CONF"
    while IFS='=' read -r key value; do
        [[ ! -z "$key" ]] && echo "env = $key,$value" >> "$HYPR_CONF"
    done < "$DMS_ENV"
    rm "$DMS_ENV"
fi
echo "exec-once = dms run" >> "$HYPR_CONF"

# --- 10. Custom Hyprland Keybinds & Workspace Rules ---
echo "Injecting custom keybinds and workspace rules..."

# Define exact DMS paths
HYPR_DIR="$HOME/.config/hypr"
DMS_DIR="$HYPR_DIR/dms"
DMS_BINDS="$DMS_DIR/binds.conf"
HYPR_CONF="$HYPR_DIR/hyprland.conf"

# Ensure the DMS directory exists (safety check)
mkdir -p "$DMS_DIR"

# 10a. Inject Custom Binds to DMS folder
# We use >> to append so we don't wipe out the DMS system binds
if [ -f "$DMS_BINDS" ] || [ -d "$DMS_DIR" ]; then
    cat <<EOF >> "$DMS_BINDS"

# --- REEGY CUSTOM BINDS ---
bind = SUPER, T, exec, sh -c "alacritty -e btop"
bind = Super, E, exec, nautilus
bind = Super, F, exec, firefox
bind = Super, Return, exec, alacritty
bind = Alt, Return, fullscreen, 1 
bind = SUPER, Q, killactive
bind = Super, W, togglefloating
EOF
    echo "Custom binds injected into $DMS_BINDS"
else
    echo "Error: Could not find $DMS_DIR. Skipping bind injection."
fi

# 10b. Inject Workspace Rules to main hyprland.conf
if [ -f "$HYPR_CONF" ]; then
    cat <<EOF >> "$HYPR_CONF"

# --- REEGY WORKSPACE RULES ---
workspace=1,monitor:HDMI-A-1
workspace=2,monitor:DP-1
workspace=3,monitor:DP-1
workspace=4,monitor:DP-1
workspace=5,monitor:DP-1
EOF
    echo "Workspace rules injected into $HYPR_CONF"
fi

# --- 11. VM Tweaks & Cleanup ---
if hostnamectl status | grep -q "virtualization"; then
    echo "env = WLR_NO_HARDWARE_CURSORS,1" >> "$HYPR_CONF"
    echo "env = WLR_RENDERER_ALLOW_SOFTWARE,1" >> "$HYPR_CONF"
fi

sudo pacman -Sc --noconfirm
echo "Deployment Complete!"

# --- 12. Security Hardening ---
if [ -f "$HOME/reegylinux/security.sh" ]; then
    chmod +x ~/reegylinux/security.sh
    ~/reegylinux/security.sh
fi
