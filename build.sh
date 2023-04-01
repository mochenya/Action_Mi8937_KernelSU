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

CLANH_GIT="https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b.git"
CLANG_BRANCH="lineage-20.0"
GCC_GIT="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git"
GCC_BRANCH="lineage-19.1"
GCC32_GIT="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git"
GCC32_BRANCH="lineage-19.1"

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

git clone --depth=1 $CLANH_GIT -b $CLANG_BRANCH ./clang
git clone --depth=1 $GCC_GIT -b $GCC_BRANCH ./gcc
git clone --depth=1 $GCC32_GIT -b $GCC32_BRANCH ./gcc32

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
