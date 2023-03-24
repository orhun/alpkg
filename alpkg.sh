#!/usr/bin/env bash

set -e

[ "$(id -u)" -eq 0 ] || _sudo='sudo'
installer='alpine-chroot-install'

export ARCH=${ARCH:="x86_64"}
export CHROOT_DIR=${CHROOT_DIR:="/alpine"}
export ALPINE_BRANCH=${ALPINE_BRANCH:="latest-stable"}
export ALPINE_PACKAGES=${ALPINE_PACKAGES:="build-base sudo doas bash bash-doc bash-completion alpine-sdk vim"}
export CHROOT_KEEP_VARS=${CHROOT_KEEP_VARS:="ARCH TERM SHELL"}

PACKAGER="Orhun Parmaksız <orhunparmaksiz@gmail.com>"

init-chroot() {
	if ! command -v "$installer" &>/dev/null; then
		echo "$installer could not be found!"
		exit
	fi

	echo "Creating a chroot in $CHROOT_DIR"
	$_sudo -E "$installer"

	echo "Preparing the build environment..."
	"$CHROOT_DIR/enter-chroot" bash <<EOF
adduser "$USER" wheel
echo "permit nopass :wheel" >/etc/doas.d/doas.conf
adduser "$USER" abuild
mkdir -p /var/cache/distfiles
chgrp abuild /var/cache/distfiles
chmod g+w /var/cache/distfiles
echo "PACKAGER=\"$PACKAGER\"" >>/etc/abuild.conf
echo "MAINTAINER=\"\$PACKAGER\"" >>/etc/abuild.conf
EOF
	"$CHROOT_DIR/enter-chroot" -u "$USER" bash -c 'abuild-keygen -a -i -n'

	echo "Ready for packaging!"
}

init-chroot
