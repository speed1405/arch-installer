# Kyber OS Custom Kernel (Arch Linux)

This directory contains the build scripts and configurations for compiling the custom Linux kernel used in Kyber OS for Arch Linux systems.

The kernel is heavily optimized for:
- **Gaming & Low Latency**: 1000Hz tick rate, Full Preemption, Schedutil governor.
- **Virtualization**: Built-in KVM, VirtIO, and VFIO (PCI Passthrough) support.
- **Laptops**: Broad support for trackpads (I2C HID, Synaptics, Elantech) and multitouch.
- **Performance & Footprint**: Modules are compressed with ZSTD, and debug symbols are stripped to drastically reduce compile time and memory overhead.

## Installation via Pacman Repository

The kernel is continuously built and released via GitHub Actions. You can easily add the repository to your Arch Linux system:

1. Open `/etc/pacman.conf` in your favorite editor (e.g., `sudo nano /etc/pacman.conf`).
2. Add the following repository block to the bottom of the file:

```ini
[kyberos]
SigLevel = Optional TrustAll
Server = https://github.com/speed1405/arch-installer/releases/download/kyberos-repo/
```

3. Update your package database and install the kernel:

```bash
sudo pacman -Sy
sudo pacman -S linux-kyberos linux-kyberos-headers
```

4. Ensure your bootloader is configured to use the new kernel (`vmlinuz-linux-kyberos` and `initramfs-linux-kyberos.img`).