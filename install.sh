#!/bin/bash
# Reegylinux: Noctalia AUR Edition
# Optimized for CachyOS + Hyprland + Dolphin

set -e

# --- 1. Multilib & Initial Bootstrap ---
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "Enabling multilib..."
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
    sudo pacman -Sy
fi

sudo pacman -S --needed --noconfirm base-devel git zsh

# --- 2. Install Yay (AUR Helper) ---
if ! command -v yay &> /dev/null; then
    echo "Installing Yay..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm && cd ~
fi

# --- 3. The Package Manifest ---
# Note: Installing 'noctalia-git' handles most dependencies automatically
MY_PACKAGES=(
    "7zip" "proton-vpn-gtk-app" "discord" "spotify-launcher" "fastfetch" 
    "fzf" "noto-fonts" "noto-fonts-cjk" "qt6ct" "vlc" "mpv" "qbittorrent" 
    "zsh-autosuggestions" "zsh-syntax-highlighting" "cava" "wl-clipboard"
    "fcitx5" "fcitx5-configtool" "fcitx5-mozc" "fcitx5-gtk" "fcitx5-qt"
    "hyprland" "ly" "swww" "grim" "slurp"
    "dolphin" "konsole" "kio-extras" "kservice" "ark" "kvantum" "nwg-look"
    "alacritty" "networkmanager" "pavucontrol" "bluez" "blueman"
)

MY_AUR_PACKAGES=(
    "anki-bin"
    "noctalia-git" # This is the star of the show
)

echo "--- Installing Official & AUR Packages ---"
sudo pacman -S --needed --noconfirm "${MY_PACKAGES[@]}"
yay -S --noconfirm "${MY_AUR_PACKAGES[@]}"

# --- 4. Personal Repo & Shell Setup ---
echo "Syncing reegylinux repository..."
[ -d "$HOME/reegylinux" ] || git clone https://github.com/docrobo20/reegylinux.git ~/reegylinux

# Symlinks for non-DE apps
mkdir -p ~/.config
[ -d "$HOME/reegylinux/mpv" ] && ln -sfn ~/reegylinux/mpv ~/.config/mpv
[ -d "$HOME/reegylinux/fastfetch" ] && ln -sfn ~/reegylinux/fastfetch ~/.config/fastfetch

# Oh My Zsh & .zshrc
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
[ -f "$HOME/reegylinux/.zshrc" ] && ln -sf "$HOME/reegylinux/.zshrc" "$HOME/.zshrc"
sudo chsh -s $(which zsh) $USER

# --- 5. Dolphin & System Integration ---
# Ensure "Open With" works in a standalone WM
sudo mkdir -p /etc/pacman.d/hooks
cat <<EOF | sudo tee /etc/pacman.d/hooks/refresh-kservice.hook
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = *
[Action]
Description = Updating KDE Service Cache...
When = PostTransaction
Exec = /usr/bin/kbuildsycoca6 --noincremental
EOF

# --- 6. Environment & Display Manager ---
# Disable the standard getty on tty2 to clear the path
sudo systemctl disable getty@tty2.service

# Enable the Ly template service specifically for tty2
sudo systemctl enable ly@tty2.service

# Force the system to boot into the graphical target
sudo systemctl set-default graphical.target
sudo sed -i '/QT_QPA_PLATFORMTHEME/d' /etc/environment
{
    echo "QT_QPA_PLATFORMTHEME=qt6ct"
    echo "XDG_CURRENT_DESKTOP=Hyprland"
    echo "XDG_SESSION_TYPE=wayland"
} | sudo tee -a /etc/environment

# --- 7. Final Hyprland Config ---
# Noctalia installed via AUR usually places its config in ~/.config/noctalia
# or uses a system-wide binary 'noctalia'
mkdir -p ~/.config/hypr
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

cat <<EOF >> "$HYPR_CONF"
# --- NOCTALIA STARTUP ---
exec-once = noctalia # Launched as a binary when installed via AUR

# --- REEGY CUSTOM BINDS ---
exec-once = fcitx5 -d
bind = SUPER, T, exec, ghostty -e btop
bind = Super, E, exec, dolphin
bind = Super, Return, exec, ghostty
EOF

echo "Deployment Complete! Reboot to start your new system."
