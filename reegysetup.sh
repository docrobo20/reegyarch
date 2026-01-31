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

# --- 7. Shell Setup & .zshrc ---
sudo chsh -s $(which zsh) $USER
ln -sf ~/reegylinux/.zshrc ~/.zshrc

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

# Custom Binds for DMS
DMS_BINDS="$HOME/.config/hypr/configs/binds.conf"
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

# Custom Workspaces for Hyprland.conf
cat <<EOF >> "$HYPR_CONF"

# --- REEGY WORKSPACE RULES ---
workspace=1,monitor:HDMI-A-1
workspace=2,monitor:DP-1
workspace=3,monitor:DP-1
workspace=4,monitor:DP-1
workspace=5,monitor:DP-1
EOF

# --- 11. VM Tweaks & Cleanup ---
if hostnamectl status | grep -q "virtualization"; then
    echo "env = WLR_NO_HARDWARE_CURSORS,1" >> "$HYPR_CONF"
    echo "env = WLR_RENDERER_ALLOW_SOFTWARE,1" >> "$HYPR_CONF"
fi

sudo pacman -Sc --noconfirm
echo "Deployment Complete! Scripts are decoupled and modular."
