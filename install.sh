#!/bin/bash

# Arch Linux Guided Installer - Modular & Beginner-Friendly
# Inspired by Archinstall 4.0 aesthetics

set -e

# --- Variables & Configuration ---
LOG_FILE="/tmp/install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Error handling
error_cleanup() {
    log "An error occurred. Check $LOG_FILE for details."
    # Unmount if mounted
    umount -R /mnt 2>/dev/null || true
}
trap error_cleanup ERR

# Mid-Century Modern Palette (Colors for TUI if possible, or just for dotfiles)
# Creams: #f3dfb4, Burnt Orange: #de6f20, Teak Brown: #4d3327
BG_CREAM="#f3dfb4"
ORANGE="#de6f20"
BROWN="#4d3327"

# --- Helper Functions ---

error_exit() {
    whiptail --title "Error" --msgbox "$1" 10 60
    echo "ERROR: $1" >&2
    exit 1
}

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

msg() {
    whiptail --title "Installation" --msgbox "$1" 10 60
}

confirm() {
    whiptail --title "$1" --yesno "$2" 10 60
}

# --- System Pre-flight Check ---
pre_flight_check() {
    log "Running System Pre-flight Checks..."

    # 1. UEFI Check
    if [ ! -d "/sys/firmware/efi" ]; then
        error_exit "UEFI not detected. This script requires UEFI mode."
    fi

    # 2. Internet Check
    if ! ping -c 1 archlinux.org >/dev/null 2>&1; then
        error_exit "No internet connection detected. Please connect to the internet first."
    fi

    # 3. Disk Space Check (Minimum 40GB)
    # This is a bit tricky to check 'total' space before selecting a disk,
    # but we can check if there's at least one disk >= 40GB.
    HAS_SPACE=false
    for disk in $(lsblk -dn -o NAME,SIZE -b | awk '$2 >= 42949672960 {print $1}'); do
        HAS_SPACE=true
        break
    done

    if [ "$HAS_SPACE" = false ]; then
        error_exit "No disk with at least 40GB of space found."
    fi

    log "Pre-flight checks passed."
}

# --- Modular Functions (Stubs for now) ---

setup_user() {
    USERNAME=$(whiptail --title "User Account" --inputbox "Enter username:" 10 60 "" 3>&1 1>&2 2>&3)
    USER_PASSWORD=$(whiptail --title "User Password" --passwordbox "Enter password for $USERNAME:" 10 60 3>&1 1>&2 2>&3)
    ROOT_PASSWORD=$(whiptail --title "Root Password" --passwordbox "Enter password for root:" 10 60 3>&1 1>&2 2>&3)
}

set_locale() {
    log "Gathering locale and timezone..."
    TIMEZONE=$(whiptail --title "Timezone" --inputbox "Enter your timezone (e.g., Europe/London):" 10 60 "UTC" 3>&1 1>&2 2>&3)
    LOCALE=$(whiptail --title "Locale" --inputbox "Enter your locale (e.g., en_US.UTF-8):" 10 60 "en_US.UTF-8" 3>&1 1>&2 2>&3)
    HOSTNAME=$(whiptail --title "Hostname" --inputbox "Enter your hostname:" 10 60 "archlinux" 3>&1 1>&2 2>&3)
}

select_kernel() {
    KERNEL=$(whiptail --title "Kernel Selection" --menu "Choose a kernel to install:" 15 60 4 \
        "linux" "Standard Arch Linux kernel" \
        "linux-zen" "Zen kernel for better desktop responsiveness" \
        "linux-lts" "Long Term Support kernel" \
        "custom" "Compile a custom kernel (Advanced)" 3>&1 1>&2 2>&3)

    if [ "$KERNEL" == "custom" ]; then
        if confirm "Custom Kernel" "Compiling a kernel takes a long time. Proceed?"; then
            COMPILE_CUSTOM=true
            KERNEL="linux" # Use standard as fallback for pacstrap
        else
            select_kernel
        fi
    fi
}

compile_custom_kernel() {
    log "Automating custom kernel compilation..."
    # Install dependencies first
    arch-chroot /mnt pacman -S base-devel bc cpio pahole xmlto kmod inetutils wget --noconfirm

    # Run the interactive part outside of a piped heredoc to preserve TTY
    arch-chroot /mnt /bin/bash -c "
    cd /tmp
    KVER=\$(wget -qO- https://www.kernel.org/finger_banner | head -n 1 | awk '{print \$NF}')
    MAJOR=\$(echo \$KVER | cut -d. -f1)
    wget https://cdn.kernel.org/pub/linux/kernel/v\$MAJOR.x/linux-\$KVER.tar.xz
    tar -xf linux-\$KVER.tar.xz
    cd linux-\$KVER
    zcat /proc/config.gz > .config || make defconfig
    echo 'Launching nconfig... Please configure your kernel.'
    make nconfig
    echo 'Starting build (this will take a while)...'
    make -j\$(nproc)
    make modules_install
    cp -v arch/x86/boot/bzImage /boot/vmlinuz-custom
    "

    # Setup mkinitcpio preset
    arch-chroot /mnt /bin/bash <<EOF
    cat <<EOT > /etc/mkinitcpio.d/custom.preset
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-custom"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-custom.img"
fallback_image="/boot/initramfs-custom-fallback.img"
EOT
    mkinitcpio -p custom
EOF
}

disk_partition() {
    confirm "Wipe Disk?" "Are you sure you want to wipe $SELECTED_DISK and auto-partition it?" || exit 1

    log "Partitioning $SELECTED_DISK..."
    # Simple GPT layout: 512MB EFI, 4GB Swap, Rest Root
    sgdisk -Z "$SELECTED_DISK"
    sgdisk -n 1:0:+512M -t 1:ef00 "$SELECTED_DISK"
    sgdisk -n 2:0:+4G -t 2:8200 "$SELECTED_DISK"
    sgdisk -n 3:0:0 -t 3:8300 "$SELECTED_DISK"

    PART_EFI="${SELECTED_DISK}1"
    PART_SWAP="${SELECTED_DISK}2"
    PART_ROOT="${SELECTED_DISK}3"

    # Handle nvme naming (e.g. /dev/nvme0n1p1)
    if [[ "$SELECTED_DISK" == *"nvme"* ]] || [[ "$SELECTED_DISK" == *"mmcblk"* ]]; then
        PART_EFI="${SELECTED_DISK}p1"
        PART_SWAP="${SELECTED_DISK}p2"
        PART_ROOT="${SELECTED_DISK}p3"
    fi

    log "Formatting partitions..."
    mkfs.fat -F32 "$PART_EFI"
    mkswap "$PART_SWAP"
    mkfs.ext4 -F "$PART_ROOT"

    log "Mounting partitions..."
    mount "$PART_ROOT" /mnt
    mkdir -p /mnt/boot
    mount "$PART_EFI" /mnt/boot
    swapon "$PART_SWAP"
}

base_install() {
    log "Installing base system..."
    # Always include git for AUR helper and base-devel for building
    pacstrap /mnt base $KERNEL linux-firmware base-devel networkmanager sudo nano git --noconfirm
    genfstab -U /mnt >> /mnt/etc/fstab

    # Enable multilib for gaming
    if [[ $BUNDLES == *"gaming"* ]]; then
        log "Enabling multilib repository..."
        sed -i '/\[multilib\]/,/Include/s/^#//' /mnt/etc/pacman.conf
        arch-chroot /mnt pacman -Sy
    fi
}

configure_system() {
    log "Configuring system..."
    arch-chroot /mnt /bin/bash <<EOF
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc
    echo "$LOCALE UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=$LOCALE" > /etc/locale.conf
    echo "$HOSTNAME" > /etc/hostname
    echo -e "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME" > /etc/hosts
    echo "root:$ROOT_PASSWORD" | chpasswd
    useradd -m -G wheel "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
EOF
}

select_software() {
    # DE Selection
    DESKTOP_ENV=$(whiptail --title "Desktop Environments" --checklist "Select Desktop Environments to install:" 15 60 3 \
        "plasma-desktop" "KDE Plasma" OFF \
        "gnome" "GNOME" OFF \
        "mate" "MATE" OFF 3>&1 1>&2 2>&3)

    # WM Selection
    WINDOW_MGR=$(whiptail --title "Window Managers" --checklist "Select Window Managers to install:" 15 60 2 \
        "hyprland" "Hyprland (Wayland)" OFF \
        "i3-gaps" "i3-gaps (X11)" OFF 3>&1 1>&2 2>&3)

    # Software Bundles
    BUNDLES=$(whiptail --title "Software Bundles" --checklist "Select software bundles to install:" 15 60 3 \
        "coding" "[Coding/Dev Suite]" OFF \
        "gaming" "[Gaming]" OFF \
        "media" "[Media/Office]" OFF 3>&1 1>&2 2>&3)

    # AUR Helper Selection
    AUR_HELPER=$(whiptail --title "AUR Helper" --menu "Choose an AUR helper:" 15 60 2 \
        "yay" "Yet Another Yaourt" \
        "paru" "Feature-packed AUR helper" 3>&1 1>&2 2>&3)
}

install_selected_software() {
    log "Installing selected software..."

    # Base dependencies for DEs
    PKGS="xorg-server xorg-xinit"

    [[ $DESKTOP_ENV == *"plasma-desktop"* ]] && PKGS+=" plasma-desktop sddm"
    [[ $DESKTOP_ENV == *"gnome"* ]] && PKGS+=" gnome gnome-extra gdm"
    [[ $DESKTOP_ENV == *"mate"* ]] && PKGS+=" mate mate-extra lightdm lightdm-gtk-greeter"

    [[ $WINDOW_MGR == *"hyprland"* ]] && PKGS+=" hyprland waybar swaybg dunst kitty rofi"
    [[ $WINDOW_MGR == *"i3-gaps"* ]] && PKGS+=" i3-gaps polybar feh dunst kitty rofi"

    # Drivers (GPU detection)
    GPU_TYPE=$(lspci | grep -iE 'vga|3d' | grep -iE 'nvidia|amd|intel' -o | head -n 1 | tr '[:upper:]' '[:lower:]')
    case $GPU_TYPE in
        nvidia) PKGS+=" nvidia nvidia-utils" ;;
        amd)    PKGS+=" xf86-video-amdgpu mesa" ;;
        intel)  PKGS+=" xf86-video-intel mesa" ;;
    esac

    # Install main packages
    arch-chroot /mnt pacman -S $PKGS --noconfirm

    # Enable Display Manager
    if [[ $DESKTOP_ENV == *"gnome"* ]]; then
        arch-chroot /mnt systemctl enable gdm
    elif [[ $DESKTOP_ENV == *"plasma-desktop"* ]]; then
        arch-chroot /mnt systemctl enable sddm
    elif [[ $DESKTOP_ENV == *"mate"* ]]; then
        arch-chroot /mnt systemctl enable lightdm
    fi

    arch-chroot /mnt systemctl enable NetworkManager
}

setup_bootloader() {
    case $BOOTLOADER in
        systemd-boot)
            log "Installing systemd-boot..."
            arch-chroot /mnt bootctl install
            # Configure loader
            cat <<EOF > /mnt/boot/loader/loader.conf
default arch.conf
timeout 3
console-mode max
editor no
EOF
            # Configure entry
            cat <<EOF > /mnt/boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-$KERNEL
initrd  /initramfs-$KERNEL.img
options root=PARTUUID=$(blkid -s PARTUUID -o value $PART_ROOT) rw
EOF
            if [ "$COMPILE_CUSTOM" = true ]; then
                cat <<EOF > /mnt/boot/loader/entries/arch-custom.conf
title   Arch Linux (Custom Kernel)
linux   /vmlinuz-custom
initrd  /initramfs-custom.img
options root=PARTUUID=$(blkid -s PARTUUID -o value $PART_ROOT) rw
EOF
            fi
            ;;
        grub)
            log "Installing GRUB..."
            arch-chroot /mnt pacman -S grub efibootmgr --noconfirm
            arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
            ;;
    esac
}

install_bundles() {
    log "Installing software bundles..."

    local BUNDLE_PKGS=""

    if [[ $BUNDLES == *"coding"* ]]; then
        BUNDLE_PKGS+=" git github-cli cmake docker dotnet-sdk mono-msbuild"
    fi

    if [[ $BUNDLES == *"gaming"* ]]; then
        BUNDLE_PKGS+=" steam lutris gamemode lib32-mesa"
    fi

    if [[ $BUNDLES == *"media"* ]]; then
        BUNDLE_PKGS+=" vlc gst-libav libreoffice-fresh"
    fi

    if [ -n "$BUNDLE_PKGS" ]; then
        arch-chroot /mnt pacman -S $BUNDLE_PKGS --noconfirm
    fi
}

install_aur_helper() {
    log "Installing $AUR_HELPER..."
    # Grant temporary passwordless sudo for makepkg
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /mnt/etc/sudoers.d/aur-build

    arch-chroot /mnt /bin/bash <<EOF
    cd /home/$USERNAME
    sudo -u $USERNAME git clone https://aur.archlinux.org/$AUR_HELPER.git
    cd $AUR_HELPER
    sudo -u $USERNAME makepkg -si --noconfirm
EOF

    # Remove temporary passwordless sudo
    rm /mnt/etc/sudoers.d/aur-build

    if [[ $BUNDLES == *"coding"* ]]; then
        log "Installing VS Code via AUR..."
        arch-chroot /mnt /bin/bash <<EOF
        sudo -u $USERNAME $AUR_HELPER -S visual-studio-code-bin --noconfirm
EOF
    fi
}

deploy_dotfiles() {
    log "Deploying dotfiles to /etc/skel..."

    # Create necessary directories in skel
    mkdir -p /mnt/etc/skel/.config/{hypr,i3,kitty,waybar,polybar}

    # Mid-Century Modern Kitty Config
    cat <<EOF > /mnt/etc/skel/.config/kitty/kitty.conf
background #f3dfb4
foreground #4d3327
color0 #4d3327
color1 #de6f20
color2 #7d812c
color3 #e8ab18
cursor #de6f20
EOF

    # Mid-Century Modern Hyprland Config
    cat <<EOF > /mnt/etc/skel/.config/hypr/hyprland.conf
monitor=,preferred,auto,1
exec-once = waybar & swaybg -c "#f3dfb4"
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(de6f20ee) rgba(e8ab18ee) 45deg
    col.inactive_border = rgba(4d3327aa)
}
decoration {
    rounding = 10
}
# Keybinds
bind = SUPER, Q, exec, kitty
bind = SUPER, C, killactive,
bind = SUPER, M, exit,
EOF

    # Mid-Century Modern i3 Config
    cat <<EOF > /mnt/etc/skel/.config/i3/config
set \$mod Mod4
font pango:monospace 10
exec --no-startup-id feh --bg-fill "#f3dfb4"
exec --no-startup-id polybar
# Mid-Century Colors
client.focused #de6f20 #de6f20 #f3dfb4 #de6f20
client.unfocused #4d3327 #4d3327 #f3dfb4 #4d3327
bindsym \$mod+Return exec kitty
bindsym \$mod+Shift+q kill
EOF

    log "Dotfiles deployed."
}

# --- Main Entry Point ---

display_manifest() {
    MANIFEST="Installation Manifest:
    -----------------------
    Disk: $SELECTED_DISK
    Kernel: $KERNEL
    Hostname: $HOSTNAME
    User: $USERNAME
    Timezone: $TIMEZONE
    Locale: $LOCALE
    Bootloader: $BOOTLOADER
    Desktop: $DESKTOP_ENV
    Window Manager: $WINDOW_MGR
    Bundles: $BUNDLES
    AUR Helper: $AUR_HELPER
    -----------------------
    WARNING: Proceeding will format the selected disk!"

    confirm "Final Confirmation" "$MANIFEST" || exit 1
}

main() {
    # Clear screen
    clear

    # Welcome Message
    whiptail --title "Arch Linux Guided Installer" \
             --msgbox "Welcome to the Guided Arch Linux Installer.\n\nThis tool will help you set up a professional Arch Linux environment with a Mid-Century Modern aesthetic." 12 70

    pre_flight_check

    # Phase 1: Information Gathering
    set_locale
    setup_user
    select_kernel
    select_software

    # Disk Selection (Part of Phase 1)
    DISK_LIST=$(lsblk -dnp -o NAME,SIZE,MODEL | awk '{print $1 " \"" $2 " " $3 " " $4 "\""}')
    SELECTED_DISK=$(eval whiptail --title \"Select Disk\" --menu \"Choose the disk to install Arch Linux on.\" 15 70 5 $DISK_LIST 3>&1 1>&2 2>&3)
    [ -z "$SELECTED_DISK" ] && error_exit "No disk selected."

    # Bootloader Selection (Part of Phase 1)
    BOOTLOADER=$(whiptail --title "Bootloader" --menu "Choose a bootloader:" 15 60 2 \
        "systemd-boot" "Modern and simple" \
        "grub" "Versatile and widely used" 3>&1 1>&2 2>&3)
    [ -z "$BOOTLOADER" ] && error_exit "No bootloader selected."

    # Final Confirmation
    display_manifest

    # Phase 2: Execution
    disk_partition
    base_install
    deploy_dotfiles
    configure_system
    setup_bootloader
    install_selected_software
    install_bundles
    install_aur_helper

    if [ "$COMPILE_CUSTOM" = true ]; then
        compile_custom_kernel
    fi

    whiptail --title "Success" --msgbox "Installation complete! Please reboot your system." 10 60
    log "Installation finished successfully."
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
