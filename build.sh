#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

echo "Build hello from root"

SCRIPTDIR=$(realpath $(dirname "$0"))
BUILD_WORKDIR_SRC=$(realpath ~/raspi-qt)
BUILD_WORKDIR=$(realpath /raspi-qt)

QEMU_KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/raw/master/kernel-qemu-4.4.13-jessie"
QEMU_KERNEL=${BUILD_WORKDIR_SRC}/kernel-qemu

IMAGE_SOURCE="http://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2017-09-08/2017-09-07-raspbian-stretch-lite.zip"
IMAGE_TMP=/tmp/raspbian.zip
IMAGE_PRISTINE=${BUILD_WORKDIR_SRC}/raspbian-stretch-lite-pristine.img
# IMAGE_DEST=${BUILD_WORKDIR}/raspbian-target.img
# IMAGE_DEST_ZIP=${BUILD_WORKDIR}/raspbian-target.zip

DOCKER_BUILD_SCRIPTS_SRC=$(realpath ${SCRIPTDIR}/docker-scripts)
DOCKER_BUILD_SCRIPTS=/docker-scripts

DOCKER_TAG="raspi-qt"

echo SCRIPTDIR=${SCRIPTDIR}
echo BUILD_WORKDIR_SRC=${BUILD_WORKDIR_SRC}
echo BUILD_WORKDIR=${BUILD_WORKDIR}
echo QEMU_KERNEL=${QEMU_KERNEL}
echo IMAGE_PRISTINE=${IMAGE_PRISTINE}
echo DOCKER_BUILD_SCRIPTS_SRC=${DOCKER_BUILD_SCRIPTS_SRC}

function cloneOrPull {
    if [ ! -d "$2" ]
    then
        git clone $1 $2 -b $3 --depth 1
    else
        git -C $2 clean -dfx
        git -C $2 reset --hard
        git -C $2 pull
    fi
} 

#########################################################
# Prepare directories
if [ ! -d ${BUILD_WORKDIR_SRC} ]
then
    mkdir -p ${BUILD_WORKDIR_SRC}
fi

#########################################################
# Prepare QEMU files
if [ -d ${QEMU_KERNEL} ]
then
    rm -Rf ${QEMU_KERNEL}
fi
if [ ! -f ${QEMU_KERNEL} ]
then
    wget ${QEMU_KERNEL_URL} -O ${QEMU_KERNEL}
fi
if [ -d ${IMAGE_PRISTINE} ]
then
    rm -Rf ${IMAGE_PRISTINE}
fi
if [ ! -f ${IMAGE_PRISTINE} ]
then
    wget ${IMAGE_SOURCE} -O ${IMAGE_TMP}
    unzip -p ${IMAGE_TMP} `unzip -Z1 ${IMAGE_TMP}` > ${IMAGE_PRISTINE}
    rm ${IMAGE_TMP}
fi

#########################################################
# Prepare docker build
if [[ "$(docker images -q ${DOCKER_TAG} 2> /dev/null)" == "" ]]; then
    docker build . --tag=${DOCKER_TAG} --file=Dockerfile.prebuilt
fi

#########################################################
# Launch docker build
echo docker run -it --rm --privileged --workdir ${DOCKER_BUILD_SCRIPTS} \
    --volume ${DOCKER_BUILD_SCRIPTS_SRC}:${DOCKER_BUILD_SCRIPTS} \
    --volume ${BUILD_WORKDIR_SRC}:${BUILD_WORKDIR} \
    --env BUILD_WORKDIR=${BUILD_WORKDIR} \
    "${DOCKER_TAG}" "build.sh"

docker run -it --rm --privileged --workdir ${DOCKER_BUILD_SCRIPTS} \
    --volume ${DOCKER_BUILD_SCRIPTS_SRC}:${DOCKER_BUILD_SCRIPTS} \
    --volume ${BUILD_WORKDIR_SRC}:${BUILD_WORKDIR} \
    --env BUILD_WORKDIR=${BUILD_WORKDIR} \
    "${DOCKER_TAG}" "build.sh"