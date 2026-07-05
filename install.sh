#!/bin/bash
set -e
cat << 'EOF'

                   _                            _        
__      _____| | ___ ___  _ __ ___   ___  | |_ ___  
\ \ /\ / / _ \ |/ __/ _ \| '_ ` _ \ / _ \ | __/ _ \ 
 \ V  V /  __/ | (_| (_) | | | | | |  __/ | || (_) |
  \_/\_/ \___|_|\___\___/|_| |_| |_|\___|  \__\___/ 
                                                    
           _ _                   _           
 _ __ __ _(_) |__   __ _ _ __   (_)_ __ ___  
| '__/ _` | | '_ \ / _` | '_ \  | | '_ ` _ \ 
| | | (_| | | | | | (_| | | | |_| | | | | | |
|_|  \__,_|_|_| |_|\__,_|_| |_(_)_|_| |_| |_|
                                             

EOF

echo "use fdisk /disk/name for partitioning..."
echo "Available disks:"
lsblk
echo

### --- ASK FOR PARTITIONS ---
read -p "Enter EFI partition (ex: /dev/sda1): " EFIPART
read -p "Enter ROOT partition (ex: /dev/sda2): " ROOTPART

### --- ASK FOR USERNAME & PASSWORD ---
read -p "Enter new username: " USERNAME
read -p "Enter full name: " FULLNAME

while true; do
    read -s -p "Enter password for $USERNAME: " USERPASS
    echo
    read -s -p "Re-enter password: " USERPASS2
    echo
    [[ "$USERPASS" == "$USERPASS2" ]] && break
    echo "Passwords do not match, try again."
done

### --- HOSTNAME ---
read -p "Enter Hostname: " HOSTNAME

### --- FORMAT DISKS ---
mkfs.fat -F32 $EFIPART
mkfs.ext4 $ROOTPART
mount $ROOTPART /mnt
mkdir -p /mnt/boot
mount $EFIPART /mnt/boot

### --- HTTPS MIRROR ---
#echo "Server = https://mirror.xeonbd.com/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

### --- BASE INSTALL
pacstrap -K /mnt base base-devel linux linux-firmware linux-headers efibootmgr vim grub networkmanager gdm gnome gnome-extra firefox chromium gimp libreoffice-fresh bluez bluez-utils noto-fonts git vim gnome-tweaks ffmpeg vlc mpv extension-manager kitty mesa vulkan-intel intel-media-driver power-profiles-daemon sof-firmware htop


genfstab -U /mnt >> /mnt/etc/fstab

### --- CHROOT CONFIGURATION ---
arch-chroot /mnt bash <<EOF

# --- LOCALE & TIME ---
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "$HOSTNAME" > /etc/hostname
timedatectl set-ntp true
timedatectl set-timezone Asia/Dhaka

# --- ROOT PASSWORD ---
echo "root:$USERPASS" | chpasswd

# --- ADD USER ---
useradd -m -G wheel $USERNAME
echo "$USERNAME:$USERPASS" | chpasswd
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
chfn -f $FULLNAME $USERNAME


# --- BOOTLOADER (UEFI) ---
grub-install --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# --- ENABLE NETWORK MANAGER & OTHERS ---
systemctl enable NetworkManager
systemctl enable power-profiles-daemon
systemctl enable bluetooth
systemctl enable gdm




### --- COPY GNOME CONFIG TO USER HOME (after chroot) ---
su $USERNAME
mkdir -p /home/$USERNAME/.config/kitty/
echo "font_size 15" >> /home/$USERNAME/.config/kitty/kitty.conf
echo "background_opacity 0.37" >> /home/$USERNAME/.config/kitty/kitty.conf
echo "hide_window_decorations titlebar-only" >> /home/$USERNAME/.config/kitty/kitty.conf
echo "remember_window_size no" >> /home/$USERNAME/.config/kitty/kitty.conf
echo "initial_window_height 21c" >> /home/$USERNAME/.config/kitty/kitty.conf
echo "initial_window_width 91c" >> /home/$USERNAME/.config/kitty/kitty.conf
chown -R $USERNAME:$USERNAME /home/$USERNAME/

# SETTING UP YAY
git clone https://aur.archlinux.org/yay /tmp/yay
cd /tmp/yay
makepkg -si --noconfirm
cd ..
rm -rf /tmp/yay



EOF
umount -R /mnt

echo "✅ Installation complete."
echo "You may reboot now."
