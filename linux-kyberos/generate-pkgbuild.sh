#!/usr/bin/env bash

# Fetch latest stable version if not provided by env
if [ -z "$KERNEL_VERSION" ]; then
    KERNEL_VERSION=$(curl -s https://www.kernel.org/releases.json | grep -A 2 '"latest_stable":' | grep '"version":' | cut -d '"' -f 4)
fi

if [ -z "$KERNEL_VERSION" ]; then
    echo "Failed to get latest stable kernel version."
    exit 1
fi

MAJOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d. -f1)

echo "Building Linux Kernel version: $KERNEL_VERSION"

# Expose version to GitHub Actions
if [ -n "$GITHUB_ENV" ]; then
    echo "KERNEL_VERSION=$KERNEL_VERSION" >> "$GITHUB_ENV"
fi

cat << 'PKGBUILD_EOF' > PKGBUILD
# Maintainer: Kyber OS
pkgbase=linux-kyberos
pkgver=__VERSION__
pkgrel=1
pkgdesc='Linux'
url='https://github.com/torvalds/linux'
arch=(x86_64)
license=(GPL2)
makedepends=(
  bc
  cpio
  gettext
  libelf
  pahole
  perl
  tar
  xz
  kmod
  xmlto
  inetutils
  git
)
options=(
  !debug
  !strip
)
source=(
  "https://cdn.kernel.org/pub/linux/kernel/v__MAJOR__.x/linux-${pkgver}.tar.xz"
  "config"
)
sha256sums=('SKIP' 'SKIP')

export KBUILD_BUILD_HOST=kyberos
export KBUILD_BUILD_USER=$pkgbase
export KBUILD_BUILD_TIMESTAMP="$(date -Ru${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH})"

prepare() {
  cd linux-${pkgver}

  # Setting up config
  cp ../config .config

  # Apply optimisations via scripts/config
  ./scripts/config --enable CONFIG_PREEMPT
  ./scripts/config --disable CONFIG_PREEMPT_VOLUNTARY
  ./scripts/config --enable CONFIG_HZ_1000
  ./scripts/config --disable CONFIG_HZ_300
  ./scripts/config --disable CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE
  ./scripts/config --enable CONFIG_CPU_FREQ_DEFAULT_GOV_SCHEDUTIL
  ./scripts/config --enable CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE
  ./scripts/config --set-str LOCALVERSION "-kyberos"

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
  ./scripts/config --disable CONFIG_SUNGEM

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
  make -s kernelrelease > version
}

build() {
  cd linux-${pkgver}
  make all -j$(nproc)
}

_package() {
  pkgdesc="The ${pkgdesc} kernel and modules"
  depends=(
    coreutils
    kmod
    initramfs
  )
  optdepends=(
    'linux-firmware: firmware images needed for some devices'
  )
  provides=(
    VIRTUALBOX-GUEST-MODULES
    WIREGUARD-MODULE
  )

  cd linux-${pkgver}
  local kernver="$(<version)"
  local modulesdir="$pkgdir/usr/lib/modules/$kernver"

  echo "Writing pkgbase..."
  echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"

  echo "Installing boot image..."
  install -Dm644 "$(make -s image_name)" "$modulesdir/vmlinuz"

  echo "Installing modules..."
  ZSTD_CLEVEL=19 make INSTALL_MOD_PATH="$pkgdir/usr" INSTALL_MOD_STRIP=1 \
    DEPMOD=/doesnt/exist modules_install

  rm -f "$modulesdir"/{source,build}
}

_package_headers() {
  pkgdesc="Headers and scripts for building modules for the ${pkgdesc} kernel"
  depends=(pahole)

  cd linux-${pkgver}
  local builddir="$pkgdir/usr/lib/modules/$(<version)/build"

  echo "Installing build files..."
  install -Dt "$builddir" -m644 .config Makefile Module.symvers System.map \
     version vmlinux
  install -Dt "$builddir/kernel" -m644 kernel/Makefile
  install -Dt "$builddir/arch/x86" -m644 arch/x86/Makefile
  cp -t "$builddir" -a scripts include arch/x86/include

  install -Dt "$builddir/tools/objtool" tools/objtool/objtool || true

  find "$builddir" -name '.*.cmd' -delete
}

pkgname=("$pkgbase" "$pkgbase-headers")

package_linux-kyberos() {
  _package
}

package_linux-kyberos-headers() {
  _package_headers
}
PKGBUILD_EOF

sed -i "s/__VERSION__/$KERNEL_VERSION/g" PKGBUILD
sed -i "s/__MAJOR__/$MAJOR_VERSION/g" PKGBUILD
