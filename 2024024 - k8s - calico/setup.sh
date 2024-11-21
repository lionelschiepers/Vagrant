#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Setting up"
whoami
pwd

sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
swapoff -a

apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl net-tools gnupg lsb-release

# systemctl restart snapd snapd.socket

snap wait system seed.loaded
snap install helm --classic