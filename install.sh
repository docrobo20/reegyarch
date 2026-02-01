#!/bin/bash

# --- 1. Package Manifest ---

# Enable multilib if it's not already enabled
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "Enabling multilib repository..."
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy
fi

# Official Repo Packages
MY_PACKAGES=(
     "7zip" "proton-vpn-gtk-app" "discord" "spotify-launcher" "fastfetch" "fcitx5" "fcitx5-configtool" "fcitx5-mozc" "fzf" "nautilus" "noto-fonts" "noto-fonts-cjk" "qt6ct" "vlc" "mpv" "qbittorrent" "zsh-autosuggestions" "zsh-syntax-highlighting" "mpv" "cava"
)

# AUR Packages
MY_AUR_PACKAGES=(
    "anki-bin"
)

# --- 2. Bootstrap & System Optimization ---
echo "Bootstrapping build essentials..."
sudo pacman -S --needed --noconfirm base-devel git zsh

THREADS=$(nproc)
if [ -f /etc/makepkg.conf ]; then
    sudo sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$THREADS\"/" /etc/makepkg.conf
    echo "Optimized makepkg for $THREADS cores."
fi

# --- 3. Install Official Packages ---
echo "Installing main application suite..."
sudo pacman -S --noconfirm "${MY_PACKAGES[@]}"

# --- 4. Personal Repo Setup ---
echo "Cloning reegylinux repository..."
# REPLACE the URL below with your actual repo
git clone https://github.com/docrobo20/reegylinux.git ~/reegylinux

# --- 5. Config Folder Imports (Symlinks) ---
echo "Setting up configuration symlinks..."
mkdir -p ~/.config
[ -d "$HOME/reegylinux/mpv" ] && ln -sfn ~/reegylinux/mpv ~/.config/mpv
[ -d "$HOME/reegylinux/fastfetch" ] && ln -sfn ~/reegylinux/fastfetch ~/.config/fastfetch

# --- 5b. Wallpaper Repository Integration ---
echo "Importing personal wallpaper collection..."

# 1. Create the standard Pictures directory if it doesn't exist
mkdir -p ~/Pictures

# 2. Symlink your repo's wallpaper folder to your home directory
# This assumes your folder in the repo is named 'wallpapers'
if [ -d "$HOME/reegylinux/wallpapers" ]; then
    ln -sfn "$HOME/reegylinux/wallpapers" "$HOME/Pictures/Wallpapers"
    echo "Personal wallpapers linked to ~/Pictures/Wallpapers"
else
    echo "Warning: 'wallpapers' folder not found in reegylinux repo. Skipping symlink."
fi

# --- 6. AUR Helper & Zsh Plugins ---
echo "Installing Yay and AUR manifest..."
git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
yay -S --noconfirm "${MY_AUR_PACKAGES[@]}"

# --- 7. Zsh & Oh My Zsh Integration ---
echo "Configuring Zsh..."

# 1. Install OMZ (Unattended)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 2. The Symlink Bridge (Fixes the 'Not Found' error for Pacman plugins)
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$ZSH_CUSTOM"
ln -sfn /usr/share/zsh/plugins/zsh-autosuggestions "$ZSH_CUSTOM/zsh-autosuggestions"
ln -sfn /usr/share/zsh/plugins/zsh-syntax-highlighting "$ZSH_CUSTOM/zsh-syntax-highlighting"

# 3. Whitelist Shell
ZSH_BIN=$(which zsh)
grep -q "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | sudo tee -a /etc/shells

# 4. Deploy .zshrc
rm -f "$HOME/.zshrc"
if [ -f "$HOME/reegylinux/.zshrc" ]; then
    ln -sf "$HOME/reegylinux/.zshrc" "$HOME/.zshrc"
else
    touch "$HOME/.zshrc"
fi

# 5. Switch Shell
sudo chsh -s "$ZSH_BIN" $USER

# --- 8. Desktop & Greeter ---
echo "Installing KDE Plasma and Ly..."
sudo pacman -S --noconfirm plasma-desktop dolphin konsole ly
sudo systemctl enable ly@tty2.service
sudo systemctl set-default graphical.target

# --- 9. DMS Installer & Logic ---
echo "Running DMS installer..."
curl -fsSL https://install.danklinux.com | sh

# 1. Enable the service so 'dms doctor' is happy
systemctl --user enable dms

# 2. Immediately stop the active service so it doesn't stay in KDE/current session
systemctl --user stop dms 2>/dev/null

# 3. Environment Variable Isolation (The standard logic we've refined)
DMS_ENV="$HOME/.config/environment.d/90-dms.conf"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
if [ -f "$DMS_ENV" ]; then
    echo -e "\n# Isolated DMS Envs" >> "$HYPR_CONF"
    grep -v '^#' "$DMS_ENV" | grep -v '^$' | sed 's/^/env = /' >> "$HYPR_CONF"
    rm "$DMS_ENV"
fi

# 4. The Trigger
# We keep 'dms run' because it handles its own startup logic inside Hyprland
echo "exec-once = dms run" >> "$HYPR_CONF"

#--- 10. Custom Hyprland Injections ---
echo "Injecting custom Hyprland settings..."

# 10a. Fcitx5 & Workspaces
cat <<EOF >> "$HYPR_CONF"

# --- JAPANESE INPUT (FCITX5) ---
exec-once = fcitx5 -d

# --- REEGY WORKSPACE RULES ---
workspace=1,monitor:HDMI-A-1
workspace=2,monitor:DP-1
workspace=3,monitor:DP-1
workspace=4,monitor:DP-1
workspace=5,monitor:DP-1
EOF

# 10b. Custom Binds to DMS folder
DMS_BINDS="$HOME/.config/hypr/dms/binds.conf"
mkdir -p "$(dirname "$DMS_BINDS")"
cat <<EOF >> "$DMS_BINDS"

# --- REEGY CUSTOM BINDS ---
bind = SUPER, T, exec, alacritty -e btop
bind = Super, E, exec, nautilus
bind = Super, F, exec, firefox
bind = Super, Return, exec, alacritty
bind = Alt, Return, fullscreen, 1 
bind = SUPER, Q, killactive
bind = Super, W, togglefloating
EOF

# --- 11. VM Tweaks & Final Cleanup ---
if hostnamectl status | grep -q "virtualization"; then
    echo "Applying VM cursor fixes..."
    echo "env = WLR_NO_HARDWARE_CURSORS,1" >> "$HYPR_CONF"
    echo "env = WLR_RENDERER_ALLOW_SOFTWARE,1" >> "$HYPR_CONF"
fi

sudo pacman -Sc --noconfirm
echo "Deployment Complete! You can now reboot."
