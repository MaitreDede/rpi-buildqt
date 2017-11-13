#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

BUILD_WORKDIR=$BUILD_WORKDIR

SCRIPTDIR=$(dirname "$0")
QEMU_KERNEL=${BUILD_WORKDIR}/kernel-qemu
QEMU_CPU=arm1176
QEMU_MACHINE=versatilepb

IMAGE_PRISTINE=${BUILD_WORKDIR}/raspbian-stretch-lite-pristine.img
IMAGE_DEST=${BUILD_WORKDIR}/raspbian-target.img
IMAGE_DEST_ZIP=${BUILD_WORKDIR}/raspbian-target.zip

MOUNT_POINT=/pi-root-mount

PI_SCRIPTS=${SCRIPTDIR}/pi-scripts

echo Copying pristine ${IMAGE_PRISTINE} to ${IMAGE_DEST}
cp ${IMAGE_PRISTINE} ${IMAGE_DEST}

echo ================================================
echo == Enlarging your image...
dd if=/dev/zero bs=1M count=2048 >> ${IMAGE_DEST}
echo "Fdisking..."
START_OF_ROOT_PARTITION=$(fdisk -l ${IMAGE_DEST} | tail -n 1 | awk '{print $2}')
(echo 'p';                          # print
 echo 'd';                          # delete
 echo '2';                          #   second partition
 echo 'n';                          # create new partition
 echo 'p';                          #   primary
 echo '2';                          #   number 2
 echo "${START_OF_ROOT_PARTITION}"; #   starting at previous offset
 echo '';                           #   ending at default (fdisk should propose max)
 echo 'p';                          # print
 echo 'w') | fdisk ${IMAGE_DEST}       # write and quit

LOOP_MAPPER_PATH=$(kpartx -avs ${IMAGE_DEST} | tail -n 1 | cut -d ' ' -f 3)
LOOP_MAPPER_PATH=/dev/mapper/${LOOP_MAPPER_PATH}
sleep 5
e2fsck -f "${LOOP_MAPPER_PATH}"
resize2fs "${LOOP_MAPPER_PATH}"
mkdir -p "${MOUNT_POINT}"

mount_image_rw() {
    mount --read-write "${LOOP_MAPPER_PATH}" "${MOUNT_POINT}"
    sleep 2
}
mount_image_ro() {
    mount --read-only "${LOOP_MAPPER_PATH}" "${MOUNT_POINT}"
    sleep 2
}

unmount_image() {
    sync
    umount "${MOUNT_POINT}"
}

echo ================================================
echo == Preparing image for direct updates...
mount_image_rw

echo ================================================
echo == Backup of original boot scripts
mv ${MOUNT_POINT}/etc/rc.local ${MOUNT_POINT}/etc/rc.local.backup
mv ${MOUNT_POINT}/etc/ld.so.preload ${MOUNT_POINT}/etc/ld.so.preload.backup
touch ${MOUNT_POINT}/etc/ld.so.preload
chmod +x ${MOUNT_POINT}/etc/ld.so.preload

echo ================================================
echo == Installation script
cp ${PI_SCRIPTS}/build.sh ${MOUNT_POINT}/etc/rc.local
chmod +x ${MOUNT_POINT}/etc/rc.local

echo ================================================
echo == Unmounting image
unmount_image

qemu-system-arm -kernel ${QEMU_KERNEL} -cpu ${QEMU_CPU} -m 256 -M ${QEMU_MACHINE} -no-reboot -serial stdio -drive file=${IMAGE_DEST},format=raw -append 'root=/dev/sda2 earlyprintk rootfstype=ext4 console=ttyAMA0 rw' -net user,hostfwd=tcp::10022-:22,hostfwd=tcp::18069-:8069 -net nic -nographic -monitor none


RPIDEV_TOOLS=${BUILD_WORKDIR}/tools
RPIDEV_SRC=${BUILD_WORKDIR}/src
RPIDEV_BUILD=${BUILD_WORKDIR}/build
RPIDEV_SYSROOT=${MOUNT_POINT}
RPIDEV_DEVICE_VERSION=pi3

QT_BUILD_VERSION=v5.9.2
QT_INSTALL_DIR=${RPIDEV_BUILD}/qt_${QT_BUILD_VERSION}
QT_INSTALL_DIR_HOST=${RPIDEV_BUILD}/qt_${QT_BUILD_VERSION}-host
QT_DEVICE_DIR=/usr/local/qt_${QT_BUILD_VERSION}

QT_BUILD_MODULES="qtdeclarative qtquickcontrols qtquickcontrols2 qtmultimedia qtsvg qtxmlpatterns qtwebsockets qtserialport qtwebchannel qtwebengine"

# configure piomxtextures
RPI_SYSROOT=${RPIDEV_SYSROOT}
COMPILER_PATH=${RPIDEV_TOOLS}/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin

# configure pkg config
PKG_CONFIG_DIR=
PKG_CONFIG_LIBDIR=${RPIDEV_SYSROOT}/usr/lib/pkgconfig:${RPIDEV_SYSROOT}/usr/share/pkgconfig:${RPIDEV_SYSROOT}/usr/lib/arm-linux-gnueabihf/pkgconfig
PKG_CONFIG_SYSROOT_DIR=${RPIDEV_SYSROOT}

### 1. Tools #################################### 
mkdir -p $(dirname $(realpath ${RPIDEV_TOOLS}))

echo
echo == Download tools ==
echo
cloneOrPull https://github.com/raspberrypi/tools.git ${RPIDEV_TOOLS} master --depth=5

echo
echo == Fix tools ==
echo
mv ${RPIDEV_TOOLS}/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin/arm-linux-gnueabihf-gcc ${RPIDEV_TOOLS}/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin/arm-linux-gnueabihf-gcc.real
mv ${RPIDEV_TOOLS}/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin/arm-linux-gnueabihf-g++ ${RPIDEV_TOOLS}/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin/arm-linux-gnueabihf-g++.real

cp ${SCRIPTDIR}/resources/gcc.sh ${RPIDEV_TOOLS}/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin/arm-linux-gnueabihf-gcc
cp ${SCRIPTDIR}/resources/gcc.sh ${RPIDEV_TOOLS}/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin/arm-linux-gnueabihf-g++

chmod +x ${RPIDEV_TOOLS}/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin/arm-linux-gnueabihf-gcc
chmod +x ${RPIDEV_TOOLS}/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin/arm-linux-gnueabihf-g++

### 2. sysroot #################################### 
ln -s ${RPIDEV_SYSROOT}/lib/arm-linux-gnueabihf ${RPIDEV_SYSROOT}/lib/arm-linux-gnueabihf/4.9.3
ln -s ${RPIDEV_SYSROOT}/usr/lib/arm-linux-gnueabihf ${RPIDEV_SYSROOT}/usr/lib/arm-linux-gnueabihf/4.9.3

### 3. qtbase #################################### 
mount_image_ro
mkdir -p ${RPIDEV_SRC}
echo
echo == Download qtbase ${QT_BUILD_VERSION} ==
echo
cloneOrPull https://github.com/qt/qtbase.git ${RPIDEV_SRC}/qtbase ${QT_BUILD_VERSION} --depth=50
SOURCE_DIR=${RPIDEV_SRC}/qtbase
pushd ${SOURCE_DIR}
rm -rf ${QT_INSTALL_DIR}
rm -rf ${QT_INSTALL_DIR_HOST}

DEVICE=
if [ "$RPIDEV_DEVICE_VERSION" == "pi1" ]; then
    DEVICE=linux-rasp-pi-g++
elif [ "$RPIDEV_DEVICE_VERSION" == "pi2" ]; then
    DEVICE=linux-rasp-pi2-g++
elif [ "$RPIDEV_DEVICE_VERSION" == "pi3" ]; then
    if [[ "$QT_BUILD_VERSION" == "v5.8"* ]]; then
        DEVICE=linux-rpi3-g++
    else
        DEVICE=linux-rasp-pi3-g++
    fi
else
    echo "${BASH_SOURCE[1]}: line ${BASH_LINENO[0]}: ${FUNCNAME[1]}: Unknown device $RPIDEV_DEVICE_VERSION." >&2
    exit 1
fi

./configure -release -opengl es2 -no-opengles3 -no-xcb -eglfs -device ${DEVICE} \
    -device-option CROSS_COMPILE=${RPIDEV_TOOLS}/arm-bcm2708/arm-rpi-4.9.3-linux-gnueabihf/bin/arm-linux-gnueabihf- \
    -sysroot ${RPIDEV_SYSROOT} -opensource -confirm-license -make libs \
    -prefix ${QT_DEVICE_DIR} -extprefix ${QT_INSTALL_DIR} -hostprefix ${QT_INSTALL_DIR_HOST} -v

make -j`grep -c ^processor /proc/cpuinfo`
make install
popd
unmount_image

### 4. modules #################################### 
MODULES=${QT_BUILD_MODULES}
for MODULE in ${MODULES}; do
        echo
        echo == Download ${MODULE} ==
        echo
        cloneOrPull https://github.com/qt/${MODULE}.git ${RPIDEV_SRC}/${MODULE} ${QT_BUILD_VERSION}
done

mount_image_ro
for MODULE in ${MODULES}; do
	QMAKE_ARGS=""
	if [ "$MODULE" == "qtwebengine" ]; then
            QMAKE_ARGS="WEBENGINE_CONFIG+=use_proprietary_codecs QMAKE_LIBDIR_OPENGL_ES2=\"/usr/lib/arm-linux-gnueabihf\" QMAKE_LIBDIR_EGL=\"/usr/lib/arm-linux-gnueabihf\""
	fi

	pushd ${RPIDEV_SRC}/$MODULE

	echo
	echo "== Configuring ${MODULE} =="
	echo
	${QT_INSTALL_DIR_HOST}/bin/qmake ${QMAKE_ARGS}

	echo
	echo "== Building ${MODULE} =="
	echo
	make -j${RPIDEV_JOBS}

	echo
	echo "== Installing ${MODULE} =="
	echo
	make install
    popd
done
unmount_image

echo ================================================
echo == Building image : restoring original files
mount_image_rw
rm ${MOUNT_POINT}/etc/rc.local ${MOUNT_POINT}/etc/ld.so.preload
mv ${MOUNT_POINT}/etc/rc.local.backup ${MOUNT_POINT}/etc/rc.local
mv ${MOUNT_POINT}/etc/ld.so.preload.backup ${MOUNT_POINT}/etc/ld.so.preload
unmount_image

echo ================================================
echo Done.
