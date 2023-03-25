#!/usr/bin/env bash

set -e

[ "$(id -u)" -eq 0 ] || _sudo='sudo'
installer='alpine-chroot-install'

export ARCH=${ARCH:="x86_64"}
export CHROOT_DIR=${CHROOT_DIR:="/alpine"}
export ALPINE_BRANCH=${ALPINE_BRANCH:="latest-stable"}
export ALPINE_PACKAGES=${ALPINE_PACKAGES:="build-base sudo doas bash bash-doc bash-completion alpine-sdk atools vim zellij"}
export CHROOT_KEEP_VARS=${CHROOT_KEEP_VARS:="ARCH TERM SHELL"}

PACKAGER="Orhun Parmaksız <orhunparmaksiz@gmail.com>"
APORTS_URL="https://gitlab.alpinelinux.org/orhun/aports"
APORTS_DIR=${APORTS_DIR:="$HOME/aports"}

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

commit_msg_hook=$(
	cat <<-'_EOF_'
		#!/bin/sh
		# https://wiki.alpinelinux.org/wiki/Creating_an_Alpine_package#Commit_your_work
		case "$2,$3" in
		  ,|template,)
		    if git diff-index --diff-filter=A --name-only --cached HEAD \
		        | grep -q '/APKBUILD$'; then
		      meta() { git diff --staged | grep "^+$1" | sed 's/.*="\?//;s/"$//';}
		      printf 'testing/%s: new aport\n\n%s\n%s\n' "$(meta pkgname)" \
		        "$(meta url)" "$(meta pkgdesc)" "$(cat $1)" > "$1"
		    else
		      printf '%s\n\n%s' `git diff-index --name-only --cached HEAD \
		        | sed -n 's/\/APKBUILD$//p;q'` "$(cat $1)" > "$1"
		    fi;;
		esac
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

init-aports() {
	git clone "$APORTS_URL" "$APORTS_DIR"
	echo "$commit_msg_hook" >"$APORTS_DIR./git/hooks/prepare-commit-msg"
	chmod +x "$APORTS_DIR./git/hooks/prepare-commit-msg"
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
# init-aports
# run ./pkg-edit.sh "${@}"
