#!/bin/sh
clear

LANG=C

# What you need installed to compile
# gcc, gpp, cpp, c++, g++, lzma, lzop, ia32-libs flex

# What you need to make configuration easier by using xconfig
# qt4-dev, qmake-qt4, pkg-config

# Setting the toolchain
# the kernel/Makefile CROSS_COMPILE variable to match the download location of the
# bin/ folder of your toolchain
# toolchain already axist and set! in kernel git. ../aarch64-linux-android-4.9/bin/

# Structure for building and using this script


# location
KERNELDIR=$(readlink -f .);

# Some variables
VER=EAS
export LOCALVERSION=~`echo $VER`
export KBUILD_BUILD_USER=DennySPB
export KBUILD_BUILD_HOST=Ubuntu

CLEANUP()
{
	# begin by ensuring the required directory structure is complete, and empty
	echo "Initialising................."
	rm -rf "$KERNELDIR"/out/boot
	rm -f "$KERNELDIR"/out/system/lib/modules/*;
	rm -f "$KERNELDIR"/out/*.zip
	rm -f "$KERNELDIR"/out/*.img
	mkdir -p "$KERNELDIR"/out/boot

	if [ -d ../Ramdisk-Gemini-tmp ]; then
		rm -rf ../Ramdisk-Gemini-tmp/*
	else
		mkdir ../Ramdisk-Gemini-tmp
		chown root:root ../Ramdisk-Gemini-tmp
		chmod 777 ../Ramdisk-Gemini-tmp
	fi;

	# force regeneration of .dtb and Image files for every compile
	rm -f arch/arm64/boot/*.dtb
	rm -f arch/arm64/boot/dts/*.dtb
	rm -f arch/arm64/boot/*.cmd
	rm -f arch/arm64/boot/zImage
	rm -f arch/arm64/boot/Image
	rm -f arch/arm64/boot/Image.gz
	rm -f arch/arm64/boot/Image.lz4
	rm -f arch/arm64/boot/Image.gz-dtb
	rm -f arch/arm64/boot/Image.lz4-dtb

	BUILD_MI5=0
}
CLEANUP;

BUILD_NOW()
{
	PYTHON_CHECK=$(ls -la /usr/bin/python | grep python3 | wc -l);
	PYTHON_WAS_3=0;

	if [ "$PYTHON_CHECK" -eq "1" ] && [ -e /usr/bin/python2 ]; then
		if [ -e /usr/bin/python2 ]; then
			rm /usr/bin/python
			ln -s /usr/bin/python2 /usr/bin/python
			echo "Switched to Python2 for building kernel will switch back when done";
			PYTHON_WAS_3=1;
		else
			echo "You need Python2 to build this kernel. install and come back."
			exit 1;
		fi;
	else
		echo "Python2 is used! all good, building!";
	fi;

	# move into the kernel directory and compile the main image
	echo "Compiling Kernel.............";
	if [ ! -f "$KERNELDIR"/.config ]; then
		if [ "$BUILD_MI5" -eq "1" ]; then
			cp arch/arm64/configs/gemini_defconfig .config
		fi;
	fi;

	# get version from config
	GETVER=$(cat "$KERNELDIR/VERSION")

	cp "$KERNELDIR"/.config "$KERNELDIR"/arch/arm64/configs/"$KERNEL_CONFIG_FILE";

	# remove all old modules before compile
	for i in $(find "$KERNELDIR"/ -name "*.ko"); do
		rm -f "$i";
	done;

	# Idea by savoca
	NR_CPUS=$(grep -c ^processor /proc/cpuinfo)

	if [ "$NR_CPUS" -le "2" ]; then
		NR_CPUS=4;
		echo "Building kernel with 4 CPU threads";
	else
		echo "Building kernel with $NR_CPUS CPU threads";
	fi;

	# build Image
	time make ARCH=arm64 CROSS_COMPILE=/home/android/aex_8.1/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-8.x/bin/aarch64-linux-android- -j $NR_CPUS

	cp "$KERNELDIR"/.config "$KERNELDIR"/arch/arm64/configs/"$KERNEL_CONFIG_FILE";

	stat "$KERNELDIR"/arch/arm64/boot/Image.gz-dtb || exit 1;

	# compile the modules, and depmod to create the final Image
	echo "Compiling Modules............"
	time make ARCH=arm64 CROSS_COMPILE=/home/android/aex_8.1/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-8.x/bin/aarch64-linux-android- modules -j ${NR_CPUS} || exit 1

	# move the compiled Image and modules into the OUT working directory
	echo "Move compiled objects........"

	# copy needed branch files to Ramdisk temp dir.
	cp -a ../Ramdisk-Gemini/* ../Ramdisk-Gemini-tmp/

	if [ ! -d "$KERNELDIR"/out/system/lib/modules ]; then
		mkdir -p "$KERNELDIR"/out/system/lib/modules;
	fi;

	for i in $(find "$KERNELDIR" -name '*.ko'); do
		cp -av "$i" "$KERNELDIR"/out/system/lib/modules/;
	done;

	chmod 755 "$KERNELDIR"/out/system/lib/modules/*

	# remove empty directory placeholders from tmp-initramfs
	for i in $(find ../Ramdisk-Gemini-tmp/ -name EMPTY_DIRECTORY); do
		rm -f "$i";
	done;

	if [ -e "$KERNELDIR"/arch/arm64/boot/Image ]; then

		if [ ! -d out/boot ]; then
			mkdir out/boot
		fi;

		cp arch/arm64/boot/Image.gz-dtb out/boot/
		cp .config out/view_only_config

		# strip not needed debugs from modules.
		/home/android/aex_8.1/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-8.x/bin/aarch64-linux-android-strip --strip-unneeded "$KERNELDIR"/out/system/lib/modules/* 2>/dev/null
		/home/android/aex_8.1/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-8.x/bin/aarch64-linux-android-strip --strip-debug "$KERNELDIR"/out/system/lib/modules/* 2>/dev/null

		# cleanup all temporary working files
		echo "Post build cleanup..........."
		cd ..
		rm -rf boot

		cd "$KERNELDIR"/out/

	else
		if [ "$PYTHON_WAS_3" -eq "1" ]; then
			rm /usr/bin/python
			ln -s /usr/bin/python3 /usr/bin/python
		fi;

		# with red-color
		echo -e "\e[1;31mKernel STUCK in BUILD! no Image exist\e[m"
	fi;
}

CLEAN_KERNEL()
{
	PYTHON_CHECK=$(ls -la /usr/bin/python | grep python3 | wc -l);
	CLEAN_PYTHON_WAS_3=0;

	if [ "$PYTHON_CHECK" -eq "1" ] && [ -e /usr/bin/python2 ]; then
		if [ -e /usr/bin/python2 ]; then
			rm /usr/bin/python
			ln -s /usr/bin/python2 /usr/bin/python
			echo "Switched to Python2 for building kernel will switch back when done";
			CLEAN_PYTHON_WAS_3=1;
		else
			echo "You need Python2 to build this kernel. install and come back."
			exit 1;
		fi;
	else
		echo "Python2 is used! all good, building!";
	fi;

	if [ -e .config ]; then
		cp -pv .config .config.bkp;
	elif [ -e .config.bkp ]; then
		rm .config.bkp
	fi;
	make ARCH=arm64 mrproper;
	make clean;
	if [ -e .config.bkp ]; then
		cp -pv .config.bkp .config;
	fi;

	if [ "$CLEAN_PYTHON_WAS_3" -eq "1" ]; then
		rm /usr/bin/python
		ln -s /usr/bin/python3 /usr/bin/python
	fi;

	# restore firmware libs*.a
	git checkout firmware/
}

export KERNEL_CONFIG=gemini_defconfig
export USE_CCACHE=true
export CCACHE_DIR="/root/.ccache"
export CXX="ccache g++"
export CC="ccache gcc"

KERNEL_CONFIG_FILE=gemini_defconfig
BUILD_MI5=1;
BUILD_NOW;
