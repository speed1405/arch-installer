#!/usr/bin/env bash
set -e
umask 022

# Fetch latest stable version
KERNEL_VERSION=$(curl -s https://www.kernel.org/releases.json | jq -r '.latest_stable.version')

if [ -z "$KERNEL_VERSION" ]; then
    echo "Failed to get latest stable kernel version."
    exit 1
fi

MAJOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d. -f1)

echo "Building Debian Linux Kernel version: $KERNEL_VERSION"

# Expose version to GitHub Actions
if [ -n "$GITHUB_ENV" ]; then
    echo "KERNEL_VERSION=$KERNEL_VERSION" >> "$GITHUB_ENV"
fi

# Download kernel
curl -O -L "https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VERSION}.x/linux-${KERNEL_VERSION}.tar.xz"
tar -xf "linux-${KERNEL_VERSION}.tar.xz"
cd "linux-${KERNEL_VERSION}"

# Make default config
make defconfig

# Apply Kyber OS optimisations via scripts/config
./scripts/config --enable CONFIG_PREEMPT
./scripts/config --disable CONFIG_PREEMPT_VOLUNTARY
./scripts/config --enable CONFIG_HZ_1000
./scripts/config --disable CONFIG_HZ_300
./scripts/config --disable CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE
./scripts/config --enable CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL
./scripts/config --enable CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE
./scripts/config --set-str LOCALVERSION "-kyberos"
./scripts/config --disable CONFIG_SYSTEM_TRUSTED_KEYS
./scripts/config --disable CONFIG_SYSTEM_REVOCATION_KEYS

# Laptop Trackpad & Multitouch
./scripts/config --enable CONFIG_I2C_HID_ACPI
./scripts/config --enable CONFIG_MOUSE_PS2_ELANTECH
./scripts/config --enable CONFIG_MOUSE_PS2_SYNAPTICS
./scripts/config --enable CONFIG_HID_MULTITOUCH

# UEFI & BIOS Compatibility
./scripts/config --enable CONFIG_EFI
./scripts/config --enable CONFIG_EFI_STUB
./scripts/config --enable CONFIG_EFI_MIXED
./scripts/config --enable CONFIG_RELOCATABLE

# Footprint & Modularity optimizations
./scripts/config --disable CONFIG_DEBUG_INFO
./scripts/config --enable CONFIG_DEBUG_INFO_NONE
./scripts/config --disable CONFIG_DEBUG_KERNEL
./scripts/config --enable CONFIG_MODULE_COMPRESS_ZSTD

# Virtualization/Gaming specific
./scripts/config --enable CONFIG_KVM
./scripts/config --enable CONFIG_KVM_INTEL
./scripts/config --enable CONFIG_KVM_AMD
./scripts/config --enable CONFIG_VIRTIO_BLK
./scripts/config --enable CONFIG_VIRTIO_NET
./scripts/config --enable CONFIG_VIRTIO_PCI
./scripts/config --enable CONFIG_VFIO
./scripts/config --enable CONFIG_VFIO_PCI
./scripts/config --enable CONFIG_VFIO_VIRQFD

make olddefconfig

# Ensure fixdep exists with executable bits before bindeb-pkg packaging stages run.
# We keep this explicit in CI as a guard even with umask normalization above.
make -j"$(nproc)" scripts/basic/fixdep
chmod 755 scripts/basic/fixdep

# Build Debian Packages
make -j"$(nproc)" bindeb-pkg

echo "Debian packages generated in $(dirname $(pwd))"
