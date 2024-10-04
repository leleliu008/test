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
    run sudo pkg install -y coreutils cmake gmake gcc pkgconf

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
    run sudo pkg_add coreutils cmake gmake gcc%11 pkgconf libarchive

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
    run sudo pkgin -y install coreutils cmake gmake pkg-config bsdtar

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
            run apt-get -y update
            run apt-get -y install curl xz-utils cmake make pkg-config g++ linux-headers-generic

            run ln -sf /usr/bin/make /usr/bin/gmake
            ;;
        alpine)
            run apk update
            run apk add cmake make pkgconf g++ linux-headers libarchive-tools
    esac
}

unset IFS

PREFIX="/opt/$1"

[ -z "$GID" ] && GID="$(id -g -n)"
[ -z "$UID" ] && UID="$(id -u -n)"

unset sudo

[ "$(id -u)" -eq 0 ] || sudo=sudo

TARGET_OS_KIND="$(printf '%s\n' "$1" | cut -d- -f3)"

__setup_$TARGET_OS_KIND

run $sudo install -d -g "$GID" -o "$UID" "$PREFIX"

[ -f cacert.pem ] && run export SSL_CERT_FILE="$PWD/cacert.pem"

run ./xbuilder install automake libtool pkgconf gmake --prefix="$PREFIX"

if command -v bsdtar > /dev/null ; then
    run bsdtar cvaPf "$1.tar.xz" "$PREFIX"
else
    run    tar cvJPf "$1.tar.xz" "$PREFIX"
fi
