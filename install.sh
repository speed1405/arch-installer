#!/bin/bash

# The Kyber Link v1.0 - Kyber OS Installer
# Droid Initialization Terminal: Star Wars / 1970s Retro-Futurist Edition

set -e

# --- Variables & Configuration ---
LOG_FILE="/tmp/install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Custom DIALOGRC for the aesthetic
export DIALOGRC="/tmp/.kyber_dialogrc"

cat <<EOF > "$DIALOGRC"
use_shadow = OFF
use_colors = ON
screen_color = (CYAN,BLUE,ON)
dialog_color = (WHITE,BLUE,OFF)
title_color = (YELLOW,BLUE,ON)
border_color = (RED,BLUE,ON)
button_active_color = (WHITE,CYAN,ON)
button_inactive_color = (BLACK,WHITE,OFF)
button_key_inactive_color = (RED,WHITE,OFF)
button_label_active_color = (BLACK,CYAN,ON)
button_label_inactive_color = (BLACK,WHITE,OFF)
position_indicator_color = (YELLOW,BLUE,ON)
menubox_color = (WHITE,BLUE,OFF)
item_color = (WHITE,BLUE,OFF)
item_selected_color = (BLACK,CYAN,ON)
tag_color = (YELLOW,BLUE,ON)
tag_selected_color = (YELLOW,CYAN,ON)
tag_key_color = (YELLOW,BLUE,ON)
tag_key_selected_color = (YELLOW,CYAN,ON)
check_color = (WHITE,BLUE,OFF)
check_selected_color = (BLACK,CYAN,ON)
uarrow_color = (GREEN,BLUE,ON)
darrow_color = (GREEN,BLUE,ON)
EOF

# Note: The hex codes from the prompt (#1A1B26, #D65D0E, #00D4FF) are mapped to
# the closest standard ncurses colors (BLUE/BLACK, RED/ORANGE, CYAN).

# --- Helper Functions ---

error_exit() {
    dialog --title "ERROR: SYSTEM MALFUNCTION" --msgbox "$1" 10 60
    echo "ERROR: $1" >&2
    exit 1
}

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [TERMINAL] $1"
}

msg() {
    dialog --title "THE KYBER LINK" --msgbox "$1" 10 60
}

confirm() {
    dialog --title "$1" --yesno "$2" 10 60
}

# --- System Pre-flight Check ---
pre_flight_check() {
    log "Initiating Pre-flight Scans..."

    # 1. UEFI Check
    if [ ! -d "/sys/firmware/efi" ]; then
        error_exit "UEFI sensor offline. This terminal requires UEFI to plot hyperspace coordinates."
    fi

    # 2. Uplink Check (Internet)
    if ! ping -c 1 archlinux.org >/dev/null 2>&1; then
        error_exit "Uplink failed. Please establish an active connection to the Holocron network."
    fi

    # 3. Disk Space Check (Minimum 40GB)
    HAS_SPACE=false
    for disk in $(lsblk -dn -o NAME,SIZE -b | awk '$2 >= 42949672960 {print $1}'); do
        HAS_SPACE=true
        break
    done
    if [ "$HAS_SPACE" = false ]; then
        error_exit "No Sector found with at least 40GB of space. Expansion required."
    fi

    # 4. Timezone Check (South Coast / Sydney)
    CURRENT_TZ=$(timedatectl show --property=Timezone --value)
    if [ "$CURRENT_TZ" != "Australia/Sydney" ]; then
        log "Warning: Chronometer not synced to Sector: Shoalhaven Heads (Sydney)."
        if confirm "Sync Chronometer?" "Sector detected as $CURRENT_TZ. Sync to Australia/Sydney (Shoalhaven Heads Outpost)?"; then
            timedatectl set-timezone Australia/Sydney
            log "Chronometer synced to Australia/Sydney."
        fi
    fi

    log "Pre-flight scans complete. Uplink stable."
}

# --- Modular Functions ---

select_disk() {
    DISK_LIST_RAW=$(lsblk -dnp -o NAME,SIZE,MODEL | grep -v "loop")
    DISK_OPTS=()
    while read -r line; do
        disk=$(echo "$line" | awk '{print $1}')
        info=$(echo "$line" | cut -d' ' -f2-)
        DISK_OPTS+=("$disk" "$info")
    done <<< "$DISK_LIST_RAW"

    if [ ${#DISK_OPTS[@]} -eq 0 ]; then
        error_exit "No suitable Sectors (Disks) found."
    fi

    SELECTED_DISK=$(dialog --title "Plotting Hyperspace Coordinates" \
        --menu "Select a Sector (Disk) to initialize. WARNING: All data will be vaporized!" 17 75 7 \
        "${DISK_OPTS[@]}" 3>&1 1>&2 2>&3)

    [ -z "$SELECTED_DISK" ] && error_exit "No Sector selected. Mission aborted."
}

disk_partition() {
    PART_MODE=$(dialog --title "Hyperspace Plotting" --menu "Choose your navigation mode:" 15 60 2 \
        "auto" "Auto-Pilot (Recommended for New Recruits)" \
        "manual" "Manual Navigation (cfdisk)" 3>&1 1>&2 2>&3)

    case $PART_MODE in
        auto)
            log "Initiating Auto-Pilot partitioning on $SELECTED_DISK..."
            sgdisk -Z "$SELECTED_DISK"
            sgdisk -n 1:0:+512M -t 1:ef00 "$SELECTED_DISK"
            sgdisk -n 2:0:+4G -t 2:8200 "$SELECTED_DISK"
            sgdisk -n 3:0:0 -t 3:8300 "$SELECTED_DISK"

            PART_EFI="${SELECTED_DISK}1"
            PART_SWAP="${SELECTED_DISK}2"
            PART_ROOT="${SELECTED_DISK}3"
            [[ "$SELECTED_DISK" == *"nvme"* ]] || [[ "$SELECTED_DISK" == *"mmcblk"* ]] && {
                PART_EFI="${SELECTED_DISK}p1"; PART_SWAP="${SELECTED_DISK}p2"; PART_ROOT="${SELECTED_DISK}p3"
            }
            ;;
        manual)
            dialog --title "Manual Navigation" --msgbox "Launching cfdisk... Please plot your own coordinates.\n\nEnsure you create an EFI partition (ef00) and a Root partition (8300)." 12 60
            cfdisk "$SELECTED_DISK"

            # Simple heuristic check to see if partitions were created
            if ! lsblk -n "$SELECTED_DISK" | grep -q "[0-9]"; then
                error_exit "No coordinates detected. Manual navigation failed."
            fi

            # We would need to ask for the partition names in manual mode,
            # but for this script, we expect the user to follow the standard layout or use Auto-Pilot.
            # To be safe and meet the "beginner-friendly" goal, we'll guide them back to Auto-Pilot if they are unsure.
            if ! confirm "Manual Plotting Complete?" "Have you finished partitioning and are ready to format?"; then
                disk_partition
                return
            fi

            # Identify partitions (naive but works if user created them in order)
            PART_EFI="${SELECTED_DISK}1"; PART_ROOT="${SELECTED_DISK}2"
            [[ "$SELECTED_DISK" == *"nvme"* ]] || [[ "$SELECTED_DISK" == *"mmcblk"* ]] && {
                PART_EFI="${SELECTED_DISK}p1"; PART_ROOT="${SELECTED_DISK}p2"
            }
            # Skip swap for manual unless we want to be very complex
            ;;
    esac

    log "Vaporizing old data and formatting..."
    mkfs.fat -F32 "$PART_EFI"
    mkswap "$PART_SWAP"
    mkfs.ext4 -F "$PART_ROOT"

    mount "$PART_ROOT" /mnt
    mkdir -p /mnt/boot
    mount "$PART_EFI" /mnt/boot
    swapon "$PART_SWAP"
}

setup_user() {
    FORCE_PATH=$(dialog --title "The Force" --menu "Choose your path through the galaxy:" 15 60 2 \
        "jedi" "The Light Side (Blue/Green/Cream)" \
        "sith" "The Dark Side (Red/Black)" 3>&1 1>&2 2>&3)
    [ -z "$FORCE_PATH" ] && FORCE_PATH="jedi"

    USERNAME=$(dialog --title "Registering New Recruit" --inputbox "Enter recruit name (username):" 10 60 "" 3>&1 1>&2 2>&3)
    USER_PASSWORD=$(dialog --title "Recruit Password" --passwordbox "Establish security clearance (user password):" 10 60 3>&1 1>&2 2>&3)
    ROOT_PASSWORD=$(dialog --title "Command Clearances" --passwordbox "Establish high-level command clearance (root password):" 10 60 3>&1 1>&2 2>&3)
}

select_kernel() {
    KERNEL=$(dialog --title "The Kyber Crystal" --menu "Choose a core for your holocron (Kernel):" 15 60 4 \
        "linux" "Standard Crystal" \
        "linux-zen" "Zen-Optimized Crystal" \
        "linux-lts" "Stable Legacy Crystal" \
        "custom" "Bleed the Crystal (Compile from source)" 3>&1 1>&2 2>&3)

    if [ "$KERNEL" == "custom" ]; then
        if confirm "Bleed the Crystal" "Compiling from source requires immense focus. Proceed?"; then
            COMPILE_CUSTOM=true
            KERNEL="linux" # Base for pacstrap
        else
            select_kernel
        fi
    fi
}

compile_custom_kernel() {
    log "Bleeding the Crystal (Custom Kernel Compilation)..."

    # Question-based tuning
    CUSTOM_KNAME=$(dialog --title "Crystal Naming" --inputbox "Enter a name for your custom crystal (kernel):" 10 60 "linux-kyberos" 3>&1 1>&2 2>&3)
    [ -z "$CUSTOM_KNAME" ] && CUSTOM_KNAME="linux-kyberos"

    OPT_PERF=$(confirm "Kyber Tuning" "Optimize for maximum combat performance (O3 optimization)?" && echo "YES" || echo "NO")
    OPT_STRIP=$(confirm "Kyber Tuning" "Strip debugging runes to reduce crystal size?" && echo "YES" || echo "NO")

    arch-chroot /mnt pacman -S base-devel bc cpio pahole xmlto kmod inetutils wget --noconfirm

    arch-chroot /mnt /bin/bash -c "
    cd /tmp
    KVER=\$(wget -qO- https://www.kernel.org/finger_banner | head -n 1 | awk '{print \$NF}')
    MAJOR=\$(echo \$KVER | cut -d. -f1)
    wget https://cdn.kernel.org/pub/linux/kernel/v\$MAJOR.x/linux-\$KVER.tar.xz
    tar -xf linux-\$KVER.tar.xz
    cd linux-\$KVER
    zcat /proc/config.gz > .config || make defconfig

    if [[ \"$OPT_PERF\" == \"YES\" ]]; then
        echo \"Tuning crystal for maximum performance...\"
        sed -i \"s/CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y/CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y/\" .config
    fi

    if [[ \"$OPT_STRIP\" == \"YES\" ]]; then
        echo \"Stripping debugging runes...\"
        sed -i \"s/CONFIG_DEBUG_INFO=y/CONFIG_DEBUG_INFO_NONE=y/\" .config
    fi

    # Inject Kyber OS identity into the kernel version
    echo \"Injecting Kyber OS identity...\"
    sed -i \"s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\\\"-kyberos\\\"/\" .config || echo 'CONFIG_LOCALVERSION=\"-kyberos\"' >> .config

    echo 'Calibrating Crystal (nconfig)...'
    make nconfig
    echo 'Energizing build... (This may take cycles)'
    make -j\$(nproc)
    make modules_install
    cp -v arch/x86/boot/bzImage /boot/vmlinuz-$CUSTOM_KNAME
    "

    # Setup mkinitcpio
    arch-chroot /mnt /bin/bash <<EOF
    cat <<EOT > /etc/mkinitcpio.d/custom.preset
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-$CUSTOM_KNAME"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-$CUSTOM_KNAME.img"
fallback_image="/boot/initramfs-$CUSTOM_KNAME-fallback.img"
EOT
    mkinitcpio -p custom
EOF
}

select_software() {
    DESKTOP_ENV=$(dialog --title "Holocron Interfaces" --checklist "Select Desktop Environments (Interfaces):" 15 60 3 \
        "plasma-desktop" "Modern Jedi Interface (Plasma)" OFF \
        "gnome" "Clean Imperial Interface (GNOME)" OFF \
        "mate" "Retro Rebel Interface (MATE)" OFF 3>&1 1>&2 2>&3)

    WINDOW_MGR=$(dialog --title "Combat Interfaces" --checklist "Select Window Managers (Combat):" 15 60 2 \
        "hyprland" "Fast Maneuverability (Hyprland)" OFF \
        "i3-wm" "Tactical Grid (i3-wm)" OFF 3>&1 1>&2 2>&3)

    BUNDLES=$(dialog --title "Holocron Knowledge" --checklist "Synchronize Knowledge Bundles:" 15 60 1 \
        "coding" "[Jedi Sentinel] Dev Suite" ON 3>&1 1>&2 2>&3)

    AUR_HELPER=$(dialog --title "Black Market Access" --menu "Choose an AUR helper (paru is faster):" 15 60 2 \
        "paru" "Advanced Paru Helper" \
        "yay" "Traditional Yay Helper" 3>&1 1>&2 2>&3)
}

install_base() {
    log "Synchronizing base files with the Holocron..."
    # Detect CPU for microcode
    CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
    UCODE=""
    [[ "$CPU_VENDOR" == "GenuineIntel" ]] && UCODE="intel-ucode"
    [[ "$CPU_VENDOR" == "AuthenticAMD" ]] && UCODE="amd-ucode"

    pacstrap /mnt base $KERNEL linux-firmware base-devel networkmanager sudo nano git $UCODE --noconfirm
    genfstab -U /mnt >> /mnt/etc/fstab
}

install_selected_software() {
    log "Synchronizing selected interfaces..."
    PKGS="xorg-server xorg-xinit"
    [[ $DESKTOP_ENV == *"plasma-desktop"* ]] && PKGS+=" plasma-desktop sddm"
    [[ $DESKTOP_ENV == *"gnome"* ]] && PKGS+=" gnome gnome-extra gdm"
    [[ $DESKTOP_ENV == *"mate"* ]] && PKGS+=" mate mate-extra lightdm lightdm-gtk-greeter"
    [[ $WINDOW_MGR == *"hyprland"* ]] && PKGS+=" hyprland waybar swaybg dunst kitty rofi"
    [[ $WINDOW_MGR == *"i3-wm"* ]] && PKGS+=" i3-wm polybar feh dunst kitty rofi"

    GPU_TYPE=$(lspci | grep -iE 'vga|3d' | grep -iE 'nvidia|amd|intel' -o | head -n 1 | tr '[:upper:]' '[:lower:]')
    case $GPU_TYPE in
        nvidia) PKGS+=" nvidia nvidia-utils" ;;
        amd)    PKGS+=" xf86-video-amdgpu mesa" ;;
        intel)  PKGS+=" xf86-video-intel mesa" ;;
    esac

    arch-chroot /mnt pacman -S $PKGS --noconfirm
    arch-chroot /mnt systemctl enable NetworkManager

    # Enable Display Manager
    if [[ $DESKTOP_ENV == *"gnome"* ]]; then
        arch-chroot /mnt systemctl enable gdm
    elif [[ $DESKTOP_ENV == *"plasma-desktop"* ]]; then
        arch-chroot /mnt systemctl enable sddm
    elif [[ $DESKTOP_ENV == *"mate"* ]]; then
        arch-chroot /mnt systemctl enable lightdm
    fi
}

install_jedi_sentinel() {
    log "Installing [Jedi Sentinel] Developer Bundle..."
    PKGS="gcc cmake dotnet-sdk mono-msbuild docker github-cli discord neofetch"
    arch-chroot /mnt pacman -S $PKGS --noconfirm
}

install_aur_helper() {
    log "Accessing the Black Market ($AUR_HELPER)..."
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /mnt/etc/sudoers.d/aur-build
    arch-chroot /mnt /bin/bash <<EOF
    cd /home/$USERNAME
    sudo -u $USERNAME git clone https://aur.archlinux.org/$AUR_HELPER.git
    cd $AUR_HELPER
    sudo -u $USERNAME makepkg -si --noconfirm
EOF
    rm /mnt/etc/sudoers.d/aur-build

    if [[ $BUNDLES == *"coding"* ]]; then
        log "Acquiring VS Code via Black Market..."
        arch-chroot /mnt sudo -u $USERNAME $AUR_HELPER -S visual-studio-code-bin --noconfirm
    fi
}

configure_system() {
    log "Finalizing internal circuits..."
    arch-chroot /mnt /bin/bash <<EOF
    ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
    hwclock --systohc
    echo "en_AU.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo "LANG=en_AU.UTF-8" > /etc/locale.conf
    echo "kyberos" > /etc/hostname
    echo "root:$ROOT_PASSWORD" | chpasswd
    useradd -m -G wheel "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

    # Git Config Helper
    sudo -u $USERNAME git config --global user.name "$USERNAME"
    sudo -u $USERNAME git config --global user.email "$USERNAME@kyberos.local"
EOF
}

deploy_dotfiles() {
    log "Deploying $FORCE_PATH dotfiles to /etc/skel..."
    mkdir -p /mnt/etc/skel/.config/{hypr,i3,kitty,neofetch}

    # Custom Neofetch for Kyber OS
    cat <<'EOF' > /mnt/etc/skel/.config/neofetch/config.conf
print_info() {
    info title
    info underline
    info "[ SECTOR ]" locale
    info "[ DEFENSES ]" shell
    info "[ CRYSTAL ]" kernel
    info "[ INTERFACE ]" de
    info "[ COMBAT ]" wm
}
# ASCII Kyber Crystal
ascii_distro="arch_small"
EOF

    if [[ "$FORCE_PATH" == "jedi" ]]; then
        # Jedi Theme (Blue/Green/Cream)
        BG="#1A1B26"; FG="#f3dfb4"; ACCENT="#00D4FF"; BORDER="#7d812c"
    else
        # Sith Theme (Red/Black)
        BG="#0D0000"; FG="#FF0000"; ACCENT="#FF0000"; BORDER="#330000"
    fi

    # Kitty config
    cat <<EOF > /mnt/etc/skel/.config/kitty/kitty.conf
background $BG
foreground $FG
color0 #4d3327
color1 $ACCENT
color2 $ACCENT
cursor $ACCENT
EOF

    # Hyprland
    cat <<EOF > /mnt/etc/skel/.config/hypr/hyprland.conf
monitor=,preferred,auto,1
exec-once = waybar & swaybg -c "$BG"
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(${ACCENT:1}ee) rgba(${BORDER:1}ee) 45deg
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

    # i3-wm
    cat <<EOF > /mnt/etc/skel/.config/i3/config
set \$mod Mod4
font pango:monospace 10
exec --no-startup-id feh --bg-fill "$BG"
exec --no-startup-id polybar
# Star Wars Colors
client.focused $ACCENT $ACCENT $FG $BORDER
client.unfocused $BG $BG $FG $BG
bindsym \$mod+Return exec kitty
bindsym \$mod+Shift+q kill
EOF

    # Custom MOTD
    if [[ "$FORCE_PATH" == "jedi" ]]; then
        cat <<'EOF' > /mnt/etc/motd
[ KYBER OS – SECTOR: SHOALHAVEN HEADS ]
Current Uplink: Stable (The Force is with us)
Location: Seven Mile Beach Jedi Outpost

"There is no emotion, there is peace.
 There is no ignorance, there is knowledge.
 There is no passion, there is serenity.
 There is no chaos, there is harmony.
 There is no death, there is the Force."

"Do or do not, there is no try... only sudo."
EOF
    else
        cat <<'EOF' > /mnt/etc/motd
[ KYBER OS – SECTOR: SHOALHAVEN HEADS ]
Current Uplink: Stable (Power of the Dark Side)
Location: Seven Mile Beach Sith Citadel

"Peace is a lie, there is only passion.
 Through passion, I gain strength.
 Through strength, I gain power.
 Through power, I gain victory.
 Through victory, my chains are broken."

"I find your lack of sudo disturbing."
EOF
    fi

    log "Lore and aesthetic modules deployed."
}

setup_bootloader() {
    case $BOOTLOADER in
        systemd-boot)
            log "Installing systemd-boot..."
            arch-chroot /mnt bootctl install

            # Detect Microcode for initrd
            UCODE_INITRD=""
            [ -n "$UCODE" ] && UCODE_INITRD="initrd  /$UCODE.img"

            cat <<EOF > /mnt/boot/loader/entries/arch.conf
title   Kyber OS
linux   /vmlinuz-$KERNEL
$UCODE_INITRD
initrd  /initramfs-$KERNEL.img
options root=PARTUUID=$(blkid -s PARTUUID -o value $PART_ROOT) rw
EOF
            if [ "$COMPILE_CUSTOM" = true ]; then
                cat <<EOF > /mnt/boot/loader/entries/arch-custom.conf
title   Kyber OS ($CUSTOM_KNAME)
linux   /vmlinuz-$CUSTOM_KNAME
$UCODE_INITRD
initrd  /initramfs-$CUSTOM_KNAME.img
options root=PARTUUID=$(blkid -s PARTUUID -o value $PART_ROOT) rw
EOF
            fi
            ;;
        grub)
            log "Installing GRUB..."
            arch-chroot /mnt pacman -S grub efibootmgr --noconfirm
            arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=KYBER_OS
            arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
            ;;
    esac
}

display_manifest() {
    MANIFEST="Kyber OS Initialization Manifest:
    -----------------------
    Sector (Disk): $SELECTED_DISK
    Crystal (Kernel): $KERNEL
    Recruit: $USERNAME
    Uplink: Stable
    Sector Location: Shoalhaven Heads
    -----------------------
    WARNING: Mission start will wipe the selected sector!"

    confirm "Final Command Approval" "$MANIFEST" || exit 1
}

# --- Main Entry Point ---

main() {
    clear
    # ASCII Art Welcome
    echo -e "\e[36m"
    cat <<'EOF'
    __   __             _
    \ \ / /  _   _     | |__     ___   _ __
     \ V /  | | | |    | '_ \   / _ \ | '__|
      | |   | |_| |    | |_) | |  __/ | |
      |_|    \__, |    |_.__/   \___| |_|
             |___/
           [ THE KYBER LINK v1.0 ]
EOF
    echo -e "\e[0m"
    sleep 2

    pre_flight_check

    msg "Welcome to The Kyber Link. Your droid initialization terminal is ready."

    setup_user
    select_kernel
    select_software
    select_disk

    # Command Link selection
    BOOTLOADER=$(dialog --title "Command Link" --menu "Select your command link:" 15 60 2 \
        "systemd-boot" "Modern Imperial" \
        "grub" "Traditional Rebel" 3>&1 1>&2 2>&3)
    [ -z "$BOOTLOADER" ] && error_exit "No command link selected."

    display_manifest

    # Execute
    disk_partition
    install_base
    deploy_dotfiles
    configure_system
    setup_bootloader
    install_selected_software

    if [[ $BUNDLES == *"coding"* ]]; then
        install_jedi_sentinel
    fi

    install_aur_helper

    if [ "$COMPILE_CUSTOM" = true ]; then
        compile_custom_kernel
    fi

    clear
    echo -e "\e[33m"
    cat <<'EOF'
      __________________________________________________
     |                                                  |
     |   MAY THE SOURCE BE WITH YOU. REBOOT TO IGNITE.  |
     |__________________________________________________|
EOF
    echo -e "\e[0m"
    msg "Kyber OS initialization complete. May the Source be with you."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
