#!/bin/bash

ubuntu_image="ubuntu_18.04_aarch64.tar.gz"

function error() {
  echo "Error: $1"
  exit 1
}

function validate() {
  if [ "$EUID" -ne 0 ]; then
    error "Script needs to be run as root"
  fi

  if [ ! -f "$ubuntu_image" ]; then
    error "Missing $ubuntu_image"
  fi

  if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <output-directory>"
    exit 0
  fi

  if [ ! -d "$1" ]; then
    error "$1 does not exists"
  fi
}

function main() {
  validate "$@"
  local rootfs="$1/rootfs"

  mkdir "$rootfs"
  sudo tar xpf "$ubuntu_image" -C "$rootfs"
  cd "$rootfs"

  sudo mount /sys ./sys -o bind
  sudo mount /proc ./proc -o bind
  sudo mount /dev ./dev -o bind

  sudo mv etc/resolv.conf etc/resolv.conf.saved
  sudo cp /etc/resolv.conf etc

  sudo chroot "$rootfs" /bin/bash -x <<'EOF'
apt-get update
apt-get install -y git software-properties-common
apt-add-repository --yes --update ppa:ansible/ansible
add-apt-repository universe
apt-get update
apt-get install -y ansible
cd /root
git clone https://github.com/PTScientists/MANIansible
cd MANIansible
ansible-playbook -i inventory.local provision.yml
EOF

  sudo umount ./sys
  sudo umount ./proc
  sudo umount ./dev

  sudo mv etc/resolv.conf.saved etc/resolv.conf

  sudo rm -rf var/lib/apt/lists/*
  sudo rm -rf dev/*
  sudo rm -rf var/log/*
  sudo rm -rf var/tmp/*
  sudo rm -rf var/cache/apt/archives/*.deb
  sudo rm -rf tmp/*

  cd "$rootfs"
  sudo tar -cpzf ../mani_ubuntu_18.04_aarch64.tar.gz .
}

main "$@"
