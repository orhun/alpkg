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
APORTS_URL="https://gitlab.alpinelinux.org/alpine/aports"
APORTS_DIR=${APORTS_DIR:="$HOME/aports"}

create-pkg-script() {
	cat <<-'_EOF_' >"$CHROOT_DIR/$HOME/pkg.sh"
		#!/usr/bin/env bash
		set -e
		pkg=""
		lint_pkg=false
		edit_pkg=true
		layout_file="$HOME/pkg-edit-layout.yml"
		while getopts "lhe" opt; do
			case ${opt} in
			e)
				edit_pkg=true
				;;
			l)
				lint_pkg=true
				;;
			h)
				echo "Usage: $0 [-e] [-l] [-h] <package>"
				echo "Options:"
				echo -e "\t-e: Edit the APKBUILD file"
				echo -e "\t-l: Lint the APKBUILD file"
				echo -e "\t-h: Show this help message"
				exit 0
				;;
			esac
		done
		cd - >/dev/null || exit
		pkg="${@: -1}"
		if [ ! -d "$pkg" ]; then
			newapkbuild "${@}"
		fi
		cd "${pkg}" || exit
		if [ "$lint_pkg" = true ]; then
			apkbuild-lint APKBUILD
		elif [ "$edit_pkg" = true ]; then
			zellij --layout "${layout_file}"
		fi
	_EOF_
	chmod +x "$CHROOT_DIR/$HOME/pkg.sh"
}

create-zellij-layout() {
	cat <<-'_EOF_' >"$CHROOT_DIR/$HOME/pkg-edit-layout.yml"
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
}

init-chroot() {
	if ! command -v "$installer" &>/dev/null; then
		echo "$installer could not be found!"
		exit 1
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
	run abuild-keygen -a -i -n

	echo "Creating scripts..."
	create-pkg-script
	create-zellij-layout

	echo "Ready for packaging!"
}

init-aports() {
	git clone "$APORTS_URL" "$APORTS_DIR"
	cat <<-'_EOF_' >"$APORTS_DIR/.git/hooks/prepare-commit-msg"
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
	chmod +x "$APORTS_DIR/.git/hooks/prepare-commit-msg"
}

fetch-pkg() {
	cd "$APORTS_DIR"
	git stash
	git checkout master
	git pull
	pkg=$(find "$(pwd)" -wholename "*/$1/APKBUILD")
	if [ -z "${pkg}" ]; then
		echo "Package is not found!"
		exit 1
	fi
	mkdir "$CHROOT_DIR/$HOME/$1"
	cp "$pkg" "$CHROOT_DIR/$HOME/$1"
	run ./pkg.sh "$1"
}

run() {
	if [ ! -d "$CHROOT_DIR" ]; then
		echo "$CHROOT_DIR is not found. Did you create the chroot?"
		exit 1
	fi
	cd "$HOME"
	"$CHROOT_DIR/enter-chroot" -u "$USER" "${@}"
}

# create-pkg-script
# init-chroot
# init-aports
# run ./pkg.sh "$1"
# run ./pkg.sh -l "$1"
# fetch-pkg "$1"
