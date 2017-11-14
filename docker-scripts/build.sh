#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

echo "Build hello from docker"

SCRIPTDIR=$(realpath $(dirname "$0"))

source ${SCRIPTDIR}/resources/lib.sh

echo ================================================
echo == Preparing image for direct updates...
initialize_image
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

echo ================================================
echo == Building application

source ${SCRIPTDIR}/build-app.sh

echo ================================================
echo == Building image : restoring original files and cleanup
mount_image_rw
rm ${MOUNT_POINT}/etc/rc.local ${MOUNT_POINT}/etc/ld.so.preload
mv ${MOUNT_POINT}/etc/rc.local.backup ${MOUNT_POINT}/etc/rc.local
mv ${MOUNT_POINT}/etc/ld.so.preload.backup ${MOUNT_POINT}/etc/ld.so.preload
unmount_image

zerofree_image

echo ================================================
echo Done.
