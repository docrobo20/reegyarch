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
     "7zip" "proton-vpn-gtk-app" "discord" "spotify-launcher" "fastfetch" "fcitx5" "fcitx5-configtool" "fcitx5-mozc" "fzf" "nautilus" "noto-fonts" "noto-fonts-cjk" "qt6ct" "vlc" "mpv" "qbittorrent" "zsh-autosuggestions" "zsh-syntax-highlighting" "mpv" 
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

# --- 6. AUR Helper & Zsh Plugins ---
echo "Installing Yay and AUR manifest..."
git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd .. && rm -rf yay
yay -S --noconfirm "${MY_AUR_PACKAGES[@]}"

# --- 7. Hardened Zsh & Oh My Zsh Configuration ---
echo "Installing Oh My Zsh and finalizing shell..."

# 1. Install Oh My Zsh (Unattended mode prevents it from opening a new shell mid-script)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 2. Ensure Zsh is whitelisted in /etc/shells for login managers
ZSH_BIN=$(which zsh)
grep -q "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | sudo tee -a /etc/shells

# 3. Deploy .zshrc and force symlink
rm -f "$HOME/.zshrc"
if [ -f "$HOME/reegylinux/.zshrc" ]; then
    ln -sf "$HOME/reegylinux/.zshrc" "$HOME/.zshrc"
else
    touch "$HOME/.zshrc"
fi

# 4. Inject AUR plugin sources
# This ensures autosuggestions and syntax highlighting work on first boot
if ! grep -q "zsh-autosuggestions.zsh" "$HOME/.zshrc"; then
    echo -e "\n# AUR Plugin Sources\nsource /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh\nsource /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> "$HOME/.zshrc"
fi

# 5. Set system shell
sudo chsh -s "$ZSH_BIN" $USER

# --- 8. Desktop & Greeter ---
echo "Installing KDE Plasma and Ly..."
sudo pacman -S --noconfirm plasma-desktop dolphin konsole ly
sudo systemctl enable ly@tty2.service
sudo systemctl set-default graphical.target

# --- 9. DMS Installer & Isolation ---
echo "Running DMS installer..."
curl -fsSL https://install.danklinux.com | sh
systemctl --user disable --now dms 2>/dev/null

# Migrate DMS variables to Hyprland then delete the global file
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

# --- 10. Custom Hyprland Injections ---
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
