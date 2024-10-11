#!/bin/sh

set -e

COLOR_GREEN='\033[0;32m'        # Green
COLOR_PURPLE='\033[0;35m'       # Purple
COLOR_OFF='\033[0m'             # Reset

echo() {
    printf '%b\n' "$*"
}

run() {
    echo "${COLOR_PURPLE}==>${COLOR_OFF} ${COLOR_GREEN}$@${COLOR_OFF}"
    eval "$@"
}

__setup_freebsd() {
    run sudo pkg install -y coreutils gmake gcc

    run sudo ln -sf /usr/local/bin/gln        /usr/bin/ln
    run sudo ln -sf /usr/local/bin/gmake      /usr/bin/make
    run sudo ln -sf /usr/local/bin/gstat      /usr/bin/stat
    run sudo ln -sf /usr/local/bin/gdate      /usr/bin/date
    run sudo ln -sf /usr/local/bin/gnproc     /usr/bin/nproc
    run sudo ln -sf /usr/local/bin/gbase64    /usr/bin/base64
    run sudo ln -sf /usr/local/bin/gunlink    /usr/bin/unlink
    run sudo ln -sf /usr/local/bin/ginstall   /usr/bin/install
    run sudo ln -sf /usr/local/bin/grealpath  /usr/bin/realpath
    run sudo ln -sf /usr/local/bin/gsha256sum /usr/bin/sha256sum
}

__setup_openbsd() {
    run sudo pkg_add coreutils gmake gcc%11 libarchive

    run sudo ln -sf /usr/local/bin/gln        /usr/bin/ln
    run sudo ln -sf /usr/local/bin/gmake      /usr/bin/make
    run sudo ln -sf /usr/local/bin/gstat      /usr/bin/stat
    run sudo ln -sf /usr/local/bin/gdate      /usr/bin/date
    run sudo ln -sf /usr/local/bin/gnproc     /usr/bin/nproc
    run sudo ln -sf /usr/local/bin/gbase64    /usr/bin/base64
    run sudo ln -sf /usr/local/bin/gunlink    /usr/bin/unlink
    run sudo ln -sf /usr/local/bin/ginstall   /usr/bin/install
    run sudo ln -sf /usr/local/bin/grealpath  /usr/bin/realpath
    run sudo ln -sf /usr/local/bin/gsha256sum /usr/bin/sha256sum
}

__setup_netbsd() {
    run sudo pkgin -y update
    run sudo pkgin -y install coreutils gmake bsdtar

    run sudo ln -sf /usr/pkg/bin/gln        /usr/bin/ln
    run sudo ln -sf /usr/pkg/bin/gmake      /usr/bin/make
    run sudo ln -sf /usr/pkg/bin/gstat      /usr/bin/stat
    run sudo ln -sf /usr/pkg/bin/gdate      /usr/bin/date
    run sudo ln -sf /usr/pkg/bin/gnproc     /usr/bin/nproc
    run sudo ln -sf /usr/pkg/bin/gbase64    /usr/bin/base64
    run sudo ln -sf /usr/pkg/bin/gunlink    /usr/bin/unlink
    run sudo ln -sf /usr/pkg/bin/ginstall   /usr/bin/install
    run sudo ln -sf /usr/pkg/bin/grealpath  /usr/bin/realpath
    run sudo ln -sf /usr/pkg/bin/gsha256sum /usr/bin/sha256sum
}

__setup_macos() {
    run brew install coreutils make
}

__setup_linux() {
    . /etc/os-release

    case $ID in
        ubuntu)
            run $sudo apt-get -y update
            run $sudo apt-get -y install curl libarchive-tools make g++ patchelf

            run $sudo ln -sf /usr/bin/make /usr/bin/gmake
            ;;
        alpine)
            run apk update
            run apk add libarchive-tools make g++
    esac
}

unset IFS

unset sudo

[ "$(id -u)" -eq 0 ] || sudo=sudo

TARGET_OS_KIND="$(printf '%s\n' "$1" | cut -d- -f3)"

__setup_$TARGET_OS_KIND

PREFIX="/opt/$1"

run $sudo install -d -g `id -g -n` -o `id -u -n` "$PREFIX"

[ -f cacert.pem ] && run export SSL_CERT_FILE="$PWD/cacert.pem"

run ./xbuilder install automake libtool pkgconf gmake --prefix="$PREFIX"

run cp -L `gcc -print-file-name=libcrypt.so.1` "$PREFIX/lib/"
LIBPERL_DIR="$(patchelf --print-rpath          "$PREFIX/bin/perl")"
run patchelf --set-rpath "$PREFIX/lib" "$LIBPERL_DIR/libperl.so"

run bsdtar cvaPf "$1.tar.xz" "$PREFIX"
