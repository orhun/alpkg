#!/usr/bin/env bash

set -e

[ "$(id -u)" -eq 0 ] || _sudo='sudo'
installer='alpine-chroot-install'

export ARCH=${ARCH:="x86_64"}
export CHROOT_DIR=${CHROOT_DIR:="/alpine"}
export ALPINE_BRANCH=${ALPINE_BRANCH:="latest-stable"}
export ALPINE_PACKAGES=${ALPINE_PACKAGES:="build-base sudo doas bash bash-doc bash-completion alpine-sdk vim zellij"}
export CHROOT_KEEP_VARS=${CHROOT_KEEP_VARS:="ARCH TERM SHELL"}

PACKAGER="Orhun Parmaksız <orhunparmaksiz@gmail.com>"

zellij_layout=$(
	cat <<-'_EOF_'
		# https://zellij.dev/old-documentation/layouts.html
		tabs:
		  - direction: Vertical
		    parts:
		      - direction: Vertical
		        focus: true
		        split_size:
		          Percent: 50
		        run:
		          command: { cmd: vim, args: ["APKBUILD"] }
		      - direction: Vertical
		        split_size:
		          Percent: 50
	_EOF_
)

edit_script=$(
	cat <<-'_EOF_'
		#!/usr/bin/env bash
		cd - >/dev/null
		pkg="\${@: -1}"
		if [ ! -d "\$pkg" ]; then
			newapkbuild "\${@}"
		fi
		cd "\${pkg}"
		zellij --layout ../pkg-layout.yml
	_EOF_
)

init-chroot() {
	if ! command -v "$installer" &>/dev/null; then
		echo "$installer could not be found!"
		exit
	fi

	echo "Creating a chroot in $CHROOT_DIR"
	$_sudo -E "$installer"

	echo "Preparing the build environment..."
	"$CHROOT_DIR/enter-chroot" bash <<-_EOF_
		adduser "$USER" wheel
		echo "permit nopass :wheel" >/etc/doas.d/doas.conf
		adduser "$USER" abuild
		mkdir -p /var/cache/distfiles
		chgrp abuild /var/cache/distfiles
		chmod g+w /var/cache/distfiles
		echo "PACKAGER=\"$PACKAGER\"" >>/etc/abuild.conf
		echo 'MAINTAINER="$PACKAGER"' >>/etc/abuild.conf
	_EOF_

	run bash <<-_EOF_
		abuild-keygen -a -i -n
		echo "$zellij_layout" >pkg-layout.yml
		echo "$edit_script" >pkg-edit.sh
		chmod +x pkg-edit.sh
	_EOF_

	echo "Ready for packaging!"
}

run() {
	if [ ! -d "$CHROOT_DIR" ]; then
		echo "$CHROOT_DIR is not found. Did you create the chroot?"
		exit
	fi
	cd "$HOME"
	"$CHROOT_DIR/enter-chroot" -u "$USER" "${@}"
}

# init-chroot
# run ./pkg-edit.sh "${@}"
