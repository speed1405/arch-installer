# Kyber OS Linux Kernel (linux-kyberos)

This directory contains the build system for `linux-kyberos`, a custom kernel optimized for Kyber OS.

## Optimizations
- **Gaming:** 1000Hz tick rate (`CONFIG_HZ_1000`), Full Preemption (`CONFIG_PREEMPT`), Schedutil CPU governor by default.
- **Virtualization:** Full KVM, VIRTIO, and VFIO (PCI Passthrough) support enabled.
- **Graphics:** Arch default base config including full support for AMD, NVIDIA (via DKMS), and Intel graphics.

## Building
This kernel is built automatically via GitHub Actions whenever changes are pushed to this directory, or it can be triggered manually. The action will always pull the latest stable release from [kernel.org](https://kernel.org).
