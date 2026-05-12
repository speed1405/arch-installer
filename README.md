# The Kyber Link v1.0

A modular Arch Linux installation script (Kyber OS) with a Star Wars-themed TUI and a 1970s retro-futurist aesthetic.

## Features

- **Initialization Sector Selector:** A new graphical interface on startup allowing you to choose between the **Graphical (Calamares)** or **Terminal (Kyber Link)** installation protocols.
- **Graphical Holocron (Calamares):** A fully themed graphical installer with Star Wars aesthetic, custom side selection (Jedi/Sith), and knowledge bundle synchronization.
- **Droid Initialization Terminal:** A custom `whiptail` TUI with Star Wars terminology and a vintage color palette.
- **Plotting Hyperspace Coordinates:** Automated and manual partitioning modes for beginners and advanced users.
- **Bleeding the Crystal:** Advanced option to compile a custom kernel from source.
- **Jedi Sentinel Bundle:** A pre-configured developer suite including Git, CMake, .NET, Docker, and VS Code.
- **Sector: Shoalhaven Heads:** Local flair for users in the Sydney/South Coast region, including customized MOTD and timezone enforcement.
- **Teak and Chrome Aesthetic:** Pre-configured dotfiles for Hyprland and i3-wm with warm browns, cream text, and glowing blue borders.

## Building the ISO

A pre-built **Kyber OS ISO** (Arch Linux base + installer bundled) is produced automatically by GitHub Actions.

### Download a release ISO

Head to the [Releases page](../../releases) and download the latest `kyber-os-*.iso`.

### Build from source via GitHub Actions

1. Go to **Actions → Build Kyber OS ISO** in this repository.
2. Click **Run workflow** (manual dispatch).
3. Leave **Publish the built ISO to GitHub Releases** unchecked if you only want a workflow artifact.
4. To publish from a manual run, enable publishing and enter a version tag such as `v1.0.0`.
5. Once the run completes, download the ISO from the **Artifacts** section or the matching GitHub release.

A release ISO is also published automatically whenever a version tag (e.g. `v1.0.0`) is pushed.

### What the build does

| Step | Detail |
|------|--------|
| Base profile | Arch's official `releng` profile (ships with `archiso`) |
| Extra packages | `libnewt` (provides `whiptail`), `reflector`, `wget` added on top of releng defaults |
| Installer | `install.sh` is placed at `/root/install.sh` (executable) inside the live environment |
| Boot message | `/etc/motd` and a `profile.d` hook remind you to run the installer on login |

### Build locally (Arch Linux host only)

```bash
# Install archiso
sudo pacman -S archiso

# Copy releng base and apply our overlay
cp -r /usr/share/archiso/configs/releng/ /tmp/kyber-profile
cat iso-profile/extra-packages.x86_64 >> /tmp/kyber-profile/packages.x86_64
cp -a iso-profile/airootfs/. /tmp/kyber-profile/airootfs/
chmod 755 /tmp/kyber-profile/airootfs/usr/local/bin/*
cp install.sh /tmp/kyber-profile/airootfs/root/install.sh
chmod 755 /tmp/kyber-profile/airootfs/root/install.sh

# Build
sudo mkarchiso -v -w /tmp/archiso-work -o ~/iso-out /tmp/kyber-profile

# Flash to USB (replace /dev/sdX with your drive)
# Use the exact ISO filename printed by mkarchiso, e.g.:
#   sudo dd bs=4M if=~/iso-out/kyber-os-2026.05-x86_64.iso of=/dev/sdX status=progress oflag=sync
ISO=$(ls ~/iso-out/kyber-os-*.iso)
sudo dd bs=4M if="$ISO" of=/dev/sdX status=progress oflag=sync
```

## Usage

1. **Boot the Kyber OS ISO.**
2. **Select your Protocol:** Upon reaching the desktop, a selector will appear.
   - **Graphical Installer (Calamares):** Recommended for most recruits. Includes a visual guide to choosing your side and software bundles.
   - **Terminal Installer (The Kyber Link):** The classic, low-level initialization protocol.
3. **Initialize:** Follow the on-screen instructions (Graphical or Terminal) to plot your coordinates and synchronize your holocron.

### Manual Terminal Trigger
If you need to trigger the terminal installer manually from a shell:
```bash
/root/install.sh
```

Alternatively, run the script directly from a stock Arch live environment:

```bash
bash <(curl -sL https://raw.githubusercontent.com/speed1405/arch-installer/main/install.sh)
```

## Disclaimer

"Do or do not, there is no try." This script will format the selected disk. Ensure all critical data is backed up before plotting your coordinates.

May the Source be with you.
