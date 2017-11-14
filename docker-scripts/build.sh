#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source ${SCRIPTDIR}/resources/lib.sh

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

launch_emulation

source ${SCRIPTDIR}/build-app.sh

echo ================================================
echo == Building image : restoring original files
mount_image_rw
rm ${MOUNT_POINT}/etc/rc.local ${MOUNT_POINT}/etc/ld.so.preload
mv ${MOUNT_POINT}/etc/rc.local.backup ${MOUNT_POINT}/etc/rc.local
mv ${MOUNT_POINT}/etc/ld.so.preload.backup ${MOUNT_POINT}/etc/ld.so.preload
unmount_image

echo ================================================
echo Done.
