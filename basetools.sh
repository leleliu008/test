#!/bin/sh

set -e

unset IFS

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

[ -f cacert.pem ] && run export SSL_CERT_FILE="$PWD/cacert.pem"

[ -f ppkg ] || {
    if command -v curl > /dev/null ; then
        run curl -LO https://raw.githubusercontent.com/leleliu008/ppkg/master/ppkg
    elif command -v wget > /dev/null ; then
        run wget     https://raw.githubusercontent.com/leleliu008/ppkg/master/ppkg
    fi
}

unset PPKG_SETUP_ARGS

unset TARGET

TARGET_OS_KIND="$(printf '%s\n' "$1" | cut -d- -f3)"

case $TARGET_OS_KIND in
    macos)
        X="${1#*-}"
        Y="${X#*-}"
        TARGET="$Y"
        PPKG_INSTALL_ARGS="--target=$TARGET" ;;
    *)  PPKG_INSTALL_ARGS='--static'
        PPKG_SETUP_ARGS='--syspm'
esac

PPKG_PKGS='coreutils findutils diffutils grep gsed gawk xxd'

run chmod a+x ppkg

run ./ppkg setup "$PPKG_SETUP_ARGS"
run ./ppkg update
run ./ppkg install "$PPKG_PKGS" "$PPKG_INSTALL_ARGS"

run install -d "$1"

DEST="$PWD/$1/"

for PKGNAME in $PPKG_PKGS
do
    if [ -z "$TARGET" ] ; then
        PKGSPEC="$PKGNAME"
    else
        PKGSPEC="$TARGET/$PKGNAME"
    fi

    PACKAGE_INSTALLED_DIR="$(./ppkg info-installed $PKGSPEC --prefix)"
    run cd "$PACKAGE_INSTALLED_DIR"
    run cp .ppkg/RECEIPT.yml "$DEST/$PKGNAME.yml"
    run cp -rf * "$DEST"
    run cd -
done

run bsdtar cvaPf "$1.tar.xz" "$1"
