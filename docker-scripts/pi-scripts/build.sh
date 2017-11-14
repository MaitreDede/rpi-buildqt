#!/usr/bin/env bash

_IP=$(hostname -I) || true
if [ "$_IP" ]; then
  printf "Hello from the pi, my IP address is %s\n" "$_IP"
fi

###################################
## functions from raspi-config
CONFIG=/boot/config.txt
set_config_var() {
  lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
  if line:match("^#?%s*"..key.."=.*$") then
    line=key.."="..value
    made_change=true
  end
  print(line)
end
if not made_change then
  print(key.."="..value)
end
EOF
mv "$3.bak" "$3"
}
###################################

# Since we are emulating, the real /boot is not mounted, 
# leading to mismatch between kernel image and modules.
UNMOUNTBOOT=0
if cat /proc/mounts | grep /dev/sda1
then
    echo /boot already mounted.
else
    echo mounting /boot
    mount /dev/sda1 /boot
    UNMOUNTBOOT=1
fi

# Recommends: antiword, graphviz, ghostscript, postgresql, python-gevent, poppler-utils
export DEBIAN_FRONTEND=noninteractive

echo Update/Upgrade
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y

echo Configuring...
# Memory split
set_config_var gpu_mem 256

# SSH
systemctl daemon-reload
systemctl enable ssh

echo Install required packages
sudo apt-get install -y git build-essential rsync jq pigpio curl libunwind8 gettext

# qtbase
PACKAGES=libboost1.55-all-dev libudev-dev libinput-dev libts-dev libmtdev-dev libjpeg-dev libfontconfig1-dev libssl-dev libdbus-1-dev libglib2.0-dev libxkbcommon-dev
# qtmultimedia
PACKAGES+= libasound2-dev libpulse-dev gstreamer1.0-omx libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
# qtwebengine
PACKAGES+= libvpx-dev libsrtp0-dev libsnappy-dev libnss3-dev
# piomxtextures
PACKAGES+= libssh-dev libsmbclient-dev libv4l-dev libbz2-dev

# # qtbase
# sudo apt-get install -y libboost1.55-all-dev libudev-dev libinput-dev libts-dev libmtdev-dev libjpeg-dev libfontconfig1-dev libssl-dev libdbus-1-dev libglib2.0-dev libxkbcommon-dev

# # qtmultimedia
# sudo apt-get install -y libasound2-dev libpulse-dev gstreamer1.0-omx libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev

# # qtwebengine
# sudo apt-get install -y libvpx-dev libsrtp0-dev libsnappy-dev libnss3-dev

# # piomxtextures
# sudo apt-get install -y libssh-dev libsmbclient-dev libv4l-dev libbz2-dev

sudo apt-get install -y ${PACKAGES}

sudo reboot