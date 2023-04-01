#!/bin/sh
#
# Copyright (C) 2023 MoChenYa mochenya20070702@gmail.com
#

WORKDIR=$(pwd)

KERENEL_GIT="https://github.com/LineageOS/android_kernel_xiaomi_msm8937.git"
KERNEL_BRANCHE="lineage-20"
KERNEL_DIR="$WORKDIR/android_kernel_xiaomi_msm8937"

DEVICES_CODE="mi8937"
DEVICE_DEFCONFIG="lineageos_mi8937_defconfig"
DEVICE_DEFCONFIG_FILE="$KERNEL_DIR/arch/arm64/configs/$DEVICE_DEFCONFIG"

CLANG_DL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-13.0.0_r37/clang-r450784d.tar.gz"
GCC_DL="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/0a0604336d4d1067aa1aaef8d3779b31fcee841d.tar.gz"
GCC32_DL="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/4d16d93f49c2b5ecdd0f12c38d194835dd595603.tar.gz"

CLANG_DIR="$WORKDIR/clang/bin"
GCC_DIR="$WORKDIR/gcc/bin"
GCC32_DIR="$WORKDIR/gcc32/bin"

export KBUILD_BUILD_USER=MoChenYa
export KBUILD_BUILD_HOST=GitHubCI

msg() {
	echo
	echo -e "\e[1;32m$*\e[0m"
	echo
}

cd $WORKDIR

# GET TOOLCHAIN
msg " • || Work on $WORKDIR ||"
msg " • || Cloning Toolchain || "

mkdir -p clang gcc gcc32
aria2c $CLANG_DL -o clang.tar.gz
aria2c $GCC_DL -o gcc.tar.gz
aria2c $GCC32_DL -o gcc32.tar.gz
tar -C clang/ -zxvf clang.tar.gz
tar -C gcc/ -zxvf gcc.tar.gz
tar -C gcc32/ -zxvf gcc32.tar.gz
rm -rf *.tar.gz

CLANG_VERSION="$($CLANG_DIR/clang --version | head -n 1)"
msg " • CLANG VERSIONS: $CLANG_VERSION "

# GET KERNEL SOURCE
msg " • || Cloning Kernel Source || "

git clone --depth=1 $KERENEL_GIT -b $KERNEL_BRANCHE $KERNEL_DIR
cd $KERNEL_DIR

# PATCH KERNELSU
msg " • || Patching KernelSU || "
for patch_file in $WORKDIR/patchs/*.patch
do
  patch -p1 < "$patch_file"
done

curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
KSU_GIT_VERSION=$(cd KernelSU && git rev-list --count HEAD)
KERNELSU_VERSION=$(($KSU_GIT_VERSION + 10000 + 200))
msg " • KernelSU version: $KERNELSU_VERSION || "

sed -i "/CONFIG_LOCALVERSION/s/\"$/-ksu-$KERNELSU_VERSION\"/" $DEVICE_DEFCONFIG_FILE

# BUILD KERNEL
msg " • || Started Compilation || "

args="ARCH=arm64 \
SUBARCH=arm64 \
CLANG_TRIPLE=aarch64-linux-gnu- \
CROSS_COMPILE=$GCC_DIR/aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=$GCC32_DIR/arm-linux-gnueabi- \
CC=$CLANG_DIR/clang \
HOSTCC=$CLANG_DIR/clang \
HOSTCXX=$CLANG_DIR/clang++"

# LINUX KERNEL VERSION
rm -rf out
make O=out $args $DEVICE_DEFCONFIG
KERNEL_VERSION=$(make O=out $args kernelversion | grep "4.9")
msg " • Linux kernel version: $KERNEL_VERSION"
make O=out $args -j"$(nproc --all)"
