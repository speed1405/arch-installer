# Kyber OS Custom Kernel (Debian/Ubuntu)

This directory contains the build scripts and configurations for compiling the custom Linux kernel used in Kyber OS, specifically packaged for Debian and Ubuntu-based systems (`.deb`).

The kernel features identical optimizations to the Arch Linux version:
- **Gaming & Low Latency**: 1000Hz tick rate, Full Preemption, Schedutil governor.
- **Virtualization**: Built-in KVM, VirtIO, and VFIO (PCI Passthrough) support.
- **Laptops**: Broad support for trackpads (I2C HID, Synaptics, Elantech) and multitouch.
- **Performance & Footprint**: Modules are compressed with ZSTD, and debug symbols are stripped to drastically reduce compile time and memory overhead.

## Installation via APT Repository

The kernel is continuously built and released via GitHub Actions as a signed APT repository hosted on GitHub Releases.

1. **Download and add the GPG Repository Key:**

```bash
curl -fsSL https://github.com/speed1405/arch-installer/releases/download/kyberos-debian-repo/kyberos-apt-key.public | sudo gpg --dearmor -o /usr/share/keyrings/kyberos-archive-keyring.gpg
```

2. **Add the Kyber OS Repository to your sources:**

```bash
echo "deb [signed-by=/usr/share/keyrings/kyberos-archive-keyring.gpg] https://github.com/speed1405/arch-installer/releases/download/kyberos-debian-repo/ ./" | sudo tee /etc/apt/sources.list.d/kyberos.list
```

3. **Update APT and Install:**

```bash
sudo apt update
sudo apt install linux-image-*-kyberos linux-headers-*-kyberos
```

*Note: The exact package version number will change depending on the latest kernel build. You can use autocomplete (`Tab`) in your terminal to find the specific version available.*