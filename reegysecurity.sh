#!/bin/bash
echo "--- Starting Security Hardening ---"

# 1. Install Security Tools
# ufw: Uncomplicated Firewall
# fail2ban: Scans logs and bans IPs with malicious intent
# lynis: Security auditing tool (great for your capstone)
# usbguard: Protects against BadUSB attacks
sudo pacman -S --noconfirm ufw fail2ban lynis usbguard

# 2. Configure Firewall
sudo systemctl enable --now ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

# 3. Secure the Shared Memory
# Prevents some types of exploits from executing in memory
if ! grep -q "tmpfs /run/shm" /etc/fstab; then
    echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" | sudo tee -a /etc/fstab
fi

# 4. USBGuard (Optional but Recommended)
# This will block any NEW USB device until you authorize it.
# Warning: If you run this, your current keyboard/mouse will be "locked"
# until you generate the initial policy.
# sudo usbguard generate-policy > /etc/usbguard/rules.conf
# sudo systemctl enable --now usbguard

# 5. Lock Root Login
# Forces you to use sudo/polkit rather than logging in as root.
sudo passwd -l root

echo "--- Hardening Complete ---"
