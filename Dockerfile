FROM ubuntu:xenial
# enable all the sources
RUN sed -i 's/^#\s*\(deb.*\)$/\1/g' /etc/apt/sources.list && \
    sed -i 's/^#\s*\(deb-src.*\)$/\1/g' /etc/apt/sources.list
# update/upgrade
RUN apt-get update && \
    apt-get install -y aptitude && \
    aptitude install -y kpartx zerofree rsync build-essential wget apt-utils flex bison unzip expect sshpass git pkg-config re2c gperf ninja python ruby gcc-multilib g++-multilib jq && \
    aptitude build-dep -y qemu-system-arm && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# download qemu
WORKDIR /root/qemu
ADD https://download.qemu.org/qemu-2.10.1.tar.xz .
# build qemu
RUN tar xJf qemu-2.10.1.tar.xz --strip-components=1 --overwrite && \
    ./configure && \
    make -j`grep -c ^processor /proc/cpuinfo` && \
    make install && \
    qemu-system-arm --version && \
    qemu-system-arm --machine help
RUN rm -Rf /root/qemu
ENTRYPOINT [ "bash" ]