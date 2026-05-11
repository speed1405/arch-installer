# Arch Linux Guided Installer

A modular, beginner-friendly Arch Linux installer with a professional TUI and a Mid-Century Modern aesthetic.

## Features

- **Guided TUI:** Uses `whiptail` for an accessible, menu-driven installation process.
- **System Pre-flight Check:** Verifies UEFI, Internet connection, and disk space before starting.
- **Auto-Partitioning:** Sets up a GPT layout with EFI, Swap, and Root partitions.
- **Desktop & WM Selection:** Choose from KDE Plasma, GNOME, MATE, Hyprland, and i3-gaps.
- **Mid-Century Modern Themes:** Pre-configured dotfiles for Hyprland and i3-gaps with a vintage color palette.
- **Custom Kernel Module:** Options for standard, Zen, LTS kernels, or an automated custom compilation flow.
- **Software Bundles:** One-click installation for Coding, Gaming, and Media suites.
- **AUR Integration:** Automated setup of `yay` or `paru`.

## Usage

To start the installation, boot from the official Arch Linux ISO and run the following command:

```bash
bash <(curl -sL https://raw.githubusercontent.com/username/arch-installer/main/install.sh)
```

*(Note: Replace the URL with the actual raw link to your script)*

## Disclaimer

This script will format the selected disk. Please ensure you have backed up all important data before proceeding.
