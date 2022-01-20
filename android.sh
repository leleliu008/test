#!/bin/sh

set -e

COLOR_RED='\033[0;31m'          # Red
COLOR_GREEN='\033[0;32m'        # Green
COLOR_YELLOW='\033[0;33m'       # Yellow
COLOR_BLUE='\033[0;94m'         # Blue
COLOR_PURPLE='\033[0;35m'       # Purple
COLOR_OFF='\033[0m'             # Reset

success() {
    printf '%b\n' "${COLOR_GREEN}[✔] $*${COLOR_OFF}"
}

die() {
    printf '%b\n' "${COLOR_RED}💔  $*${COLOR_OFF}" >&2
    exit 1
}

run() {
    printf '%b\n' "${COLOR_PURPLE}==>${COLOR_OFF} ${COLOR_GREEN}$*${COLOR_OFF}"
    eval "$*"
}

# examples:
# build_and_install_the_given_arch armv7a
# build_and_install_the_given_arch aarch64
# build_and_install_the_given_arch i686
# build_and_install_the_given_arch x86_64
build_and_install_the_given_arch() {
    run tree   --version
    run file   --version
    run rustup --version
    run rustc  --version
    run cargo  --version

    # https://github.com/actions/virtual-environments/blob/main/images/linux/Ubuntu2004-Readme.md#environment-variables-3
    # https://docs.github.com/en/actions/learn-github-actions/environment-variables#default-environment-variables
    if [ "$GITHUB_ACTIONS" = true ] ; then
        export ANDROID_NDK_HOME="$ANDROID_NDK_LATEST_HOME"
        export ANDROID_NDK_ROOT="$ANDROID_NDK_LATEST_HOME"
    else
        if [ -z "$ANDROID_NDK_HOME" ] && [ -z "$ANDROID_NDK_ROOT" ] ; then
            die "please set and export ANDROID_NDK_HOME environment"
        elif [ -n "$ANDROID_NDK_HOME" ] ; then
            export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
        else
            export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
        fi
    fi

    run "env | sed -n '/^ANDROID_NDK/p'"

    run cat "$ANDROID_NDK_HOME/source.properties"

    HOST_OS_TYPE=$(uname | tr A-Z a-z)
    HOST_OS_ARCH=$(uname -m)

    ANDROID_NDK_TOOLCHAIN_DIR=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$HOST_OS_TYPE-$HOST_OS_ARCH

    # https://crates.io/crates/cc
    # https://docs.rs/cc/latest/cc/
    # https://github.com/alexcrichton/cc-rs
    export HOST_CC=cc
    export HOST_CXX=c++
    export HOST_AR=ar

    if [ "$1" = armv7a ] ; then
        export TARGET_CC=armv7a-linux-androideabi21-clang
    else
        export TARGET_CC=$1-linux-android21-clang
    fi

    export TARGET_CXX="${TARGET_CC}++"
    export TARGET_AR=llvm-ar

    export TARGET_CFLAGS="--sysroot $ANDROID_NDK_TOOLCHAIN_DIR/sysroot"
    export TARGET_CXXFLAGS="$TARGET_CFLAGS"

    if [ "$1" = armv7a ] ; then
        export RUST_TARGET=armv7-linux-androideabi
    else
        export RUST_TARGET=$1-linux-android
    fi

    RUST_TARGET_UPPERCASE_UNDERSCORE=$(printf '%s\n' "$RUST_TARGET" | tr a-z A-Z | tr - _)

    # https://doc.rust-lang.org/cargo/reference/config.html#environment-variables
    # https://doc.rust-lang.org/cargo/reference/environment-variables.html
    export "CARGO_TARGET_${RUST_TARGET_UPPERCASE_UNDERSCORE}_AR"="$TARGET_AR"
    export "CARGO_TARGET_${RUST_TARGET_UPPERCASE_UNDERSCORE}_LINKER"="$TARGET_CC"

    # https://github.com/rust-lang/rust/pull/85806
    TEMPDIR=$(mktemp -d)
    export RUSTFLAGS="-Clink-arg=-L$TEMPDIR"
    echo 'INPUT(-lunwind)' > $TEMPDIR/libgcc.a

    shift

    run ls -l

    export PATH="$ANDROID_NDK_TOOLCHAIN_DIR/bin:$PATH"

    # https://libraries.io/cargo/cc
    run rustup target add $RUST_TARGET

    run cargo install --target $RUST_TARGET --path . --root=./install.d $@
}

help() {
    echo "USAGE:

${COLOR_GREEN}./android.sh <TARGET-ARCH> [cargo install options]${COLOR_OFF}

${COLOR_GREEN}TARGET-ARCH${COLOR_OFF} : one of armv7a, aarch64, i686, x86_64, all

${COLOR_GREEN}cargo install options${COLOR_OFF} : --target and --path have been set for you. you do not need to set.

EXAMPLES:

${COLOR_GREEN}./android.sh aarch64${COLOR_OFF}

${COLOR_GREEN}./android.sh all${COLOR_OFF}

${COLOR_GREEN}./android.sh aarch64 -vv${COLOR_OFF}
"
}

main() {
    case $1 in
        ''|-h|--help) help ; exit 0 ;;
        -*)           help ; exit 1 ;;
    esac

    TARGET_ARCHS="$1"
    if [ "$TARGET_ARCHS" = all ] ; then
           TARGET_ARCHS="armv7a aarch64 i686 x86_64"
    else
        TARGET_ARCHS=$(printf '%s\n' "$TARGET_ARCHS" | tr ',' ' ')
    fi

    shift

    for TARGET_ARCH in $TARGET_ARCHS
    do
        (build_and_install_the_given_arch $TARGET_ARCH $@)
    done
}

main $@
