#!/bin/bash

# The Kyber Link v1.0 - Kyber OS Installer
# Droid Initialization Terminal: Star Wars / 1970s Retro-Futurist Edition

set -e

# --- Variables & Configuration ---
LOG_FILE="/tmp/install.log"
exec 9>>"$LOG_FILE"
trap 'exec 9>&-' EXIT

# Custom whiptail/newt colors for the aesthetic
export NEWT_COLORS='
root=cyan,blue
border=red,blue
window=white,blue
shadow=black,black
title=yellow,blue
button=black,white
actbutton=black,cyan
checkbox=white,blue
actcheckbox=yellow,cyan
entry=white,blue
compactbutton=yellow,blue
actlistbox=black,cyan
'

# --- Helper Functions ---

error_exit() {
    whiptail --title "ERROR: SYSTEM MALFUNCTION" --msgbox "$1" 10 60
    echo "ERROR: $1" >&2
    exit 1
}

log() {
    local message
    message="$(date +'%Y-%m-%d %H:%M:%S') - [TERMINAL] $1"
    echo "$message"
    echo "$message" >&9
}

msg() {
    whiptail --title "THE KYBER LINK" --msgbox "$1" 10 60
}

confirm() {
    whiptail --title "$1" --yesno "$2" 10 60
}

print_centered_block() {
    local term_width pad line
    term_width=$(tput cols 2>/dev/null || echo 80)
    while IFS= read -r line; do
        pad=$(( (term_width - ${#line}) / 2 ))
        [ "$pad" -lt 0 ] && pad=0
        printf '%*s%s\n' "$pad" '' "$line"
    done
}

has_selection() {
    # Returns 0 when the first argument is present in the remaining arguments.
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
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

optimize_mirrors() {
    log "Optimizing Holocron network uplinks (Mirrors)..."
    # Ensure reflector is installed in the live environment
    if command -v reflector >/dev/null 2>&1; then
        reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    else
        log "Warning: reflector tool not found. Using default uplinks."
    fi
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

    SELECTED_DISK=$(whiptail --title "Plotting Hyperspace Coordinates" \
        --menu "Select a Sector (Disk) to initialize. WARNING: All data will be vaporized!" 17 75 7 \
        "${DISK_OPTS[@]}" 3>&1 1>&2 2>&3)

    [ -z "$SELECTED_DISK" ] && error_exit "No Sector selected. Mission aborted."
}

disk_partition() {
    PART_MODE=$(whiptail --title "Hyperspace Plotting" --menu "Choose your navigation mode:" 15 60 2 \
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
            whiptail --title "Manual Navigation" --msgbox "Launching cfdisk... Please plot your own coordinates.\n\nEnsure you create an EFI partition (ef00) and a Root partition (8300)." 12 60
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

            # Manual Identification
            PART_EFI=$(whiptail --title "Identify EFI" --inputbox "Enter the EFI partition path (e.g., ${SELECTED_DISK}1):" 10 60 3>&1 1>&2 2>&3)
            PART_ROOT=$(whiptail --title "Identify Root" --inputbox "Enter the Root partition path (e.g., ${SELECTED_DISK}2):" 10 60 3>&1 1>&2 2>&3)
            PART_SWAP=$(whiptail --title "Identify Swap" --inputbox "Enter the Swap partition path (Leave blank if none):" 10 60 3>&1 1>&2 2>&3)
            ;;
    esac

    log "Vaporizing old data and formatting..."
    mkfs.fat -F32 "$PART_EFI"
    mkfs.ext4 -F "$PART_ROOT"

    mount "$PART_ROOT" /mnt
    mkdir -p /mnt/boot
    mount "$PART_EFI" /mnt/boot

    if [ -n "$PART_SWAP" ]; then
        mkswap "$PART_SWAP"
        swapon "$PART_SWAP"
    fi
}

setup_user() {
    FORCE_PATH=$(whiptail --title "The Force" --menu "Choose your path through the galaxy:" 15 60 2 \
        "jedi" "The Light Side (Blue/Green/Cream)" \
        "sith" "The Dark Side (Red/Black)" 3>&1 1>&2 2>&3)
    [ -z "$FORCE_PATH" ] && FORCE_PATH="jedi"

    USERNAME=$(whiptail --title "Registering New Recruit" --inputbox "Enter recruit name (username):" 10 60 "" 3>&1 1>&2 2>&3)
    USER_PASSWORD=$(whiptail --title "Recruit Password" --passwordbox "Establish security clearance (user password):" 10 60 3>&1 1>&2 2>&3)
    ROOT_PASSWORD=$(whiptail --title "Command Clearances" --passwordbox "Establish high-level command clearance (root password):" 10 60 3>&1 1>&2 2>&3)
}

select_kernel() {
    KERNEL=$(whiptail --title "The Kyber Crystal" --menu "Choose a core for your holocron (Kernel):" 15 60 4 \
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
    CUSTOM_KNAME=$(whiptail --title "Crystal Naming" --inputbox "Enter a name for your custom crystal (kernel):" 10 60 "linux-kyber-os" 3>&1 1>&2 2>&3)
    [ -z "$CUSTOM_KNAME" ] && CUSTOM_KNAME="linux-kyber-os"

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
    sed -i \"s/^CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\\\"-kyber-os\\\"/\" .config || echo 'CONFIG_LOCALVERSION=\"-kyber-os\"' >> .config

    echo 'Calibrating Crystal (nconfig)...'
    make nconfig
    echo 'Scanning Crystal (Energizing build)... This may take many cycles.'
    # Simple spinner simulation during make
    # Explicitly building bzImage and modules
    make -j\$(nproc) bzImage modules &
    PID=\$!
    chars=\"/-\\|\"
    while kill -0 \$PID 2>/dev/null; do
        for i in {1..4}; do
            echo -ne \"\\r[\${chars:\$i-1:1}] Scanning Crystal... \"
            sleep 0.5
        done
    done
    wait \$PID
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
    INTERFACES=$(whiptail --title "Holocron Interfaces" --separate-output --checklist "Select Desktop Environments and Window Managers:" 18 70 7 \
        "plasma-desktop" "Desktop Environment: Modern Jedi Interface (Plasma)" OFF \
        "gnome" "Desktop Environment: Clean Imperial Interface (GNOME)" OFF \
        "mate" "Desktop Environment: Retro Rebel Interface (MATE)" OFF \
        "hyprland" "Fast Maneuverability (Hyprland)" OFF \
        "i3-wm" "Tactical Grid (i3-wm)" OFF \
        "dwm" "Dynamic Minimalist (dwm)" OFF \
        "openbox" "Rebel Outpost (Openbox)" OFF 3>&1 1>&2 2>&3)
    whiptail_status=$?
    [ "$whiptail_status" -ne 0 ] && error_exit "Interface selection cancelled. Mission aborted."
    [ -z "$INTERFACES" ] && error_exit "Select at least one desktop environment or window manager."

    DESKTOP_ENV_SELECTIONS=()
    WINDOW_MGR_SELECTIONS=()
    mapfile -t INTERFACE_LIST < <(printf '%s\n' "$INTERFACES")
    [ ${#INTERFACE_LIST[@]} -eq 0 ] && error_exit "Unable to parse the selected interfaces."
    for interface in "${INTERFACE_LIST[@]}"; do
        case "$interface" in
            plasma-desktop|gnome|mate)
                DESKTOP_ENV_SELECTIONS+=("$interface")
                ;;
            hyprland|i3-wm|dwm|openbox)
                WINDOW_MGR_SELECTIONS+=("$interface")
                ;;
        esac
    done

    BUNDLES=$(whiptail --title "Holocron Knowledge" --separate-output --checklist "Synchronize Knowledge Bundles:" 15 60 3 \
        "coding" "[Jedi Sentinel] Dev Suite" ON \
        "gaming" "[Podracing] Gaming Bundle" OFF \
        "media" "[Archives] Media/Office" OFF 3>&1 1>&2 2>&3)

    AUR_HELPER=$(whiptail --title "Black Market Access" --menu "Choose an AUR helper (paru is faster):" 15 60 2 \
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

    # Enable Multilib
    if [[ "$ENABLE_MULTILIB" == "YES" ]]; then
        log "Unlocking [multilib] archives..."
        sed -i "/\[multilib\]/,/Include/s/^#//" /mnt/etc/pacman.conf
        arch-chroot /mnt pacman -Sy
    fi
}

install_selected_software() {
    log "Synchronizing selected interfaces..."
    PKGS="xorg-server xorg-xinit"
    has_selection "plasma-desktop" "${DESKTOP_ENV_SELECTIONS[@]}" && PKGS+=" plasma-desktop sddm"
    has_selection "gnome" "${DESKTOP_ENV_SELECTIONS[@]}" && PKGS+=" gnome gnome-extra gdm"
    has_selection "mate" "${DESKTOP_ENV_SELECTIONS[@]}" && PKGS+=" mate mate-extra lightdm lightdm-gtk-greeter"
    has_selection "hyprland" "${WINDOW_MGR_SELECTIONS[@]}" && PKGS+=" hyprland waybar swaybg dunst kitty rofi"
    has_selection "i3-wm" "${WINDOW_MGR_SELECTIONS[@]}" && PKGS+=" i3-wm polybar xorg-xsetroot dunst kitty rofi"
    has_selection "openbox" "${WINDOW_MGR_SELECTIONS[@]}" && PKGS+=" openbox obconf lxappearance-obconf xorg-xsetroot kitty rofi"

    GPU_TYPE=$(lspci | grep -iE 'vga|3d' | grep -iE 'nvidia|amd|intel' -o | head -n 1 | tr '[:upper:]' '[:lower:]')
    case $GPU_TYPE in
        nvidia) PKGS+=" nvidia-dkms nvidia-utils dkms" ;;
        amd)    PKGS+=" xf86-video-amdgpu mesa" ;;
        intel)  PKGS+=" xf86-video-intel mesa" ;;
    esac

    arch-chroot /mnt pacman -S $PKGS --noconfirm
    arch-chroot /mnt systemctl enable NetworkManager

    # DWM Installation and Theming
    if has_selection "dwm" "${WINDOW_MGR_SELECTIONS[@]}"; then
        log "Acquiring DWM dependencies..."
        arch-chroot /mnt pacman -S libx11 libxft libxinerama --noconfirm

        log "Initializing DWM with $FORCE_PATH theme..."
        arch-chroot /mnt /bin/bash <<EOF
        cd /tmp
        git clone https://git.suckless.org/dwm
        cd dwm
        # Define theme colors
        if [[ "$FORCE_PATH" == "jedi" ]]; then
            BG="#1A1B26"; FG="#f3dfb4"; SEL="#00D4FF"; SELFG="#1A1B26"
        else
            BG="#0D0000"; FG="#FF0000"; SEL="#FF0000"; SELFG="#000000"
        fi

        # Patch config.def.h (Correct standard dwm variable names)
        sed -i "s/static const char col_gray1\[\] *= .*/static const char col_gray1[] = \"\$BG\";/" config.def.h
        sed -i "s/static const char col_gray2\[\] *= .*/static const char col_gray2[] = \"\$BG\";/" config.def.h
        sed -i "s/static const char col_gray3\[\] *= .*/static const char col_gray3[] = \"\$FG\";/" config.def.h
        sed -i "s/static const char col_gray4\[\] *= .*/static const char col_gray4[] = \"\$SELFG\";/" config.def.h
        sed -i "s/static const char col_cyan\[\] *= .*/static const char col_cyan[] = \"\$SEL\";/" config.def.h

        make install
EOF
    fi

    # Enable Display Manager
    if has_selection "gnome" "${DESKTOP_ENV_SELECTIONS[@]}"; then
        arch-chroot /mnt systemctl enable gdm
    elif has_selection "plasma-desktop" "${DESKTOP_ENV_SELECTIONS[@]}"; then
        arch-chroot /mnt systemctl enable sddm
    elif has_selection "mate" "${DESKTOP_ENV_SELECTIONS[@]}"; then
        arch-chroot /mnt systemctl enable lightdm
    fi
}

install_jedi_sentinel() {
    log "Installing [Jedi Sentinel] Developer Bundle..."
    # Note: mono-msbuild is AUR, removed from here
    PKGS="gcc cmake dotnet-sdk docker github-cli discord neofetch"
    arch-chroot /mnt pacman -S $PKGS --noconfirm
}

install_gaming_bundle() {
    log "Installing [Podracing] Gaming Bundle..."
    PKGS="steam lutris gamemode"
    # Multilib was already enabled in install_base if user chose YES
    arch-chroot /mnt pacman -S $PKGS --noconfirm
}

install_media_bundle() {
    log "Installing [Archives] Media/Office Bundle..."
    PKGS="vlc gst-libav libreoffice-fresh"
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
        log "Acquiring VS Code and Mono Game tools via Black Market..."
        arch-chroot /mnt sudo -u $USERNAME $AUR_HELPER -S visual-studio-code-bin mono-msbuild --noconfirm
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
    echo "kyber-os" > /etc/hostname
    echo "root:$ROOT_PASSWORD" | chpasswd
    useradd -m -G wheel "$USERNAME"
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
    echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

    # Git Config Helper
    sudo -u $USERNAME git config --global user.name "$USERNAME"
    sudo -u $USERNAME git config --global user.email "$USERNAME@kyber-os.local"
EOF
}

deploy_dotfiles() {
    log "Deploying $FORCE_PATH dotfiles to /etc/skel..."
    mkdir -p /mnt/etc/skel/.config/{hypr,i3,openbox,kitty,neofetch}

    # xinitrc for dwm/i3 (Take the first one selected as primary)
    # Map package names to binary names
    RAW_WM="${WINDOW_MGR_SELECTIONS[0]}"
    if [ -n "$RAW_WM" ]; then
        case $RAW_WM in
            hyprland) BIN_WM="Hyprland" ;;
            i3-wm)    BIN_WM="i3"       ;;
            dwm)      BIN_WM="dwm"      ;;
            openbox)  BIN_WM="openbox-session" ;;
            *)        BIN_WM="$RAW_WM"  ;;
        esac
        log "Primary window manager for xinitrc set to: $BIN_WM"

        cat <<EOF > /mnt/etc/skel/.xinitrc
exec $BIN_WM
EOF
    fi

    # DWM Desktop Entry for Display Managers
    if has_selection "dwm" "${WINDOW_MGR_SELECTIONS[@]}"; then
        mkdir -p /mnt/usr/share/xsessions
        cat <<EOF > /mnt/usr/share/xsessions/dwm.desktop
[Desktop Entry]
Encoding=UTF-8
Name=DWM
Comment=Dynamic Window Manager
Exec=dwm
Icon=dwm
Type=XSession
EOF
    fi

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

# Custom ASCII Logo (Simulation)
#   /\\
#  |  |
#  |  |
#   \\/
EOF

    if [[ "$FORCE_PATH" == "jedi" ]]; then
        # Jedi Theme (Blue/Green/Cream)
        BG="#1A1B26"; FG="#f3dfb4"; ACCENT="#00D4FF"; BORDER="#7d812c"
    else
        # Sith Theme (Red/Black)
        BG="#0D0000"; FG="#FF0000"; ACCENT="#FF0000"; BORDER="#330000"
    fi

    # Background logic
    if [[ "$FORCE_PATH" == "jedi" ]]; then
        # Force background to Blue/Teak
        BG_HEX="#1A1B26"
    else
        # Force background to Sith Black/Red
        BG_HEX="#0D0000"
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

    # i3-wm (Ensure it only runs if i3 is actually the selected WM or if multiple are installed)
    mkdir -p /mnt/etc/skel/.config/i3
    cat <<EOF > /mnt/etc/skel/.config/i3/config
set \$mod Mod4
font pango:monospace 10
exec --no-startup-id xsetroot -solid "$BG"
exec --no-startup-id polybar
# Star Wars Colors
client.focused $ACCENT $ACCENT $FG $BORDER
client.unfocused $BG $BG $FG $BG
bindsym \$mod+Return exec kitty
bindsym \$mod+Shift+q kill
EOF

    # Openbox config
    mkdir -p /mnt/etc/skel/.config/openbox
    cat <<EOF > /mnt/etc/skel/.config/openbox/rc.xml
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <theme>
    <name>Clearlooks</name>
    <cornerRadius>4</cornerRadius>
  </theme>
</openbox_config>
EOF

    cat <<EOF > /mnt/etc/skel/.config/openbox/autostart
xsetroot -solid "$BG" &
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
    print_centered_block <<'EOF'
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
    optimize_mirrors

    msg "Welcome to The Kyber Link. Your droid initialization terminal is ready."

    setup_user
    select_kernel
    select_software
    select_disk

    # Command Link selection
    BOOTLOADER=$(whiptail --title "Command Link" --menu "Select your command link:" 15 60 2 \
        "systemd-boot" "Modern Imperial" \
        "grub" "Traditional Rebel" 3>&1 1>&2 2>&3)
    [ -z "$BOOTLOADER" ] && error_exit "No command link selected."

    # Multilib selection
    ENABLE_MULTILIB=$(confirm "Multilib Repository" "Enable [multilib] repository (Recommended for 32-bit apps like Steam/Gaming)?" && echo "YES" || echo "NO")

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
    if [[ $BUNDLES == *"gaming"* ]]; then
        install_gaming_bundle
    fi
    if [[ $BUNDLES == *"media"* ]]; then
        install_media_bundle
    fi

    install_aur_helper

    if [ "$COMPILE_CUSTOM" = true ]; then
        compile_custom_kernel
    fi

    clear
    echo -e "\e[33m"
    print_centered_block <<'EOF'
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
