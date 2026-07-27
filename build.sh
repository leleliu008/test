#!/bin/sh

# Copyright (c) 2024-2026 刘富频
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


ARG0="$0"

set -e

# If IFS is not set, the default value will be <space><tab><newline>
# https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_05_03
unset IFS

COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;94m'
COLOR_PURPLE='\033[0;35m'
COLOR_OFF='\033[0m'

print() {
    printf '%b' "$*"
}

echo() {
    printf '%b\n' "$*"
}

note() {
    printf '%b\n' "${COLOR_YELLOW}🔔  $*${COLOR_OFF}" >&2
}

warn() {
    printf '%b\n' "${COLOR_YELLOW}🔥  $*${COLOR_OFF}" >&2
}

success() {
    printf '%b\n' "${COLOR_GREEN}[✔] $*${COLOR_OFF}" >&2
}

error() {
    printf '%b\n' "${COLOR_RED}💔  $ARG0: $*${COLOR_OFF}" >&2
}

abort() {
    EXIT_STATUS_CODE="$1"
    shift
    printf '%b\n' "${COLOR_RED}💔  $ARG0: $*${COLOR_OFF}" >&2
    exit "$EXIT_STATUS_CODE"
}

run() {
    echo "${COLOR_PURPLE}==>${COLOR_OFF} ${COLOR_GREEN}$@${COLOR_OFF}"
    eval "$@"
}

isInteger() {
    case "${1#[+-]}" in
        (*[!0123456789]*) return 1 ;;
        ('')              return 1 ;;
        (*)               return 0 ;;
    esac
}

# wfetch <URL> [--uri=<URL-MIRROR>] [--sha256=<SHA256>] [-o <OUTPUT-PATH>] [--no-buffer]
#
# If -o <OUTPUT-PATH> option is unspecified, the result will be written to <PWD>/$(basename <URL>).
#
# If <OUTPUT-PATH> is . .. ./ ../ or ends with slash(/), then it will be treated as a directory, otherwise, it will be treated as a filepath.
#
# If <OUTPUT-PATH> is -, then it will be treated as /dev/stdout.
#
# If <OUTPUT-PATH> is treated as a directory, then it will be expanded to <OUTPUT-PATH>/$(basename <URL>)
#
wfetch() {
    unset FETCH_UTS
    unset FETCH_SHA

    unset FETCH_URL
    unset FETCH_URI

    unset FETCH_PATH

    unset FETCH_OUTPUT_DIR
    unset FETCH_OUTPUT_FILEPATH
    unset FETCH_OUTPUT_FILENAME

    unset FETCH_BUFFER_FILEPATH

    unset FETCH_SHA256_EXPECTED

    unset NOT_BUFFER

    [ -z "$1" ] && abort 1 "wfetch <URL> [OPTION]... , <URL> must be non-empty."

    if [ -z "$URL_TRANSFORM" ] ; then
        FETCH_URL="$1"
    else
        FETCH_URL="$("$URL_TRANSFORM" "$1")" || return 1
    fi

    shift

    while [ -n "$1" ]
    do
        case $1 in
            --uri=*)
                FETCH_URI="${1#*=}"
                ;;
            --sha256=*)
                FETCH_SHA256_EXPECTED="${1#*=}"
                ;;
            -o) shift
                if [ -z "$1" ] ; then
                    abort 1 "wfetch <URL> -o <PATH> , <PATH> must be non-empty."
                else
                    FETCH_PATH="$1"
                fi
                ;;
            --no-buffer)
                NOT_BUFFER=1
                ;;
            *)  abort 1 "wfetch <URL> [--uri=<URL-MIRROR>] [--sha256=<SHA256>] [-o <PATH>] [-q] , unrecognized option: $1"
        esac
        shift
    done

    if [ -z "$FETCH_URI" ] ; then
        # remove query params
        FETCH_URI="${FETCH_URL%%'?'*}"
        FETCH_URI="https://fossies.org/linux/misc/${FETCH_URI##*/}"
    else
        if [ -n "$URL_TRANSFORM" ] ; then
            FETCH_URI="$("$URL_TRANSFORM" "$FETCH_URI")" || return 1
        fi
    fi

    case $FETCH_PATH in
        -)  FETCH_BUFFER_FILEPATH='-' ;;
        .|'')
            FETCH_OUTPUT_DIR='.'
            FETCH_OUTPUT_FILEPATH="$FETCH_OUTPUT_DIR/${FETCH_URL##*/}"
            ;;
        ..)
            FETCH_OUTPUT_DIR='..'
            FETCH_OUTPUT_FILEPATH="$FETCH_OUTPUT_DIR/${FETCH_URL##*/}"
            ;;
        */)
            FETCH_OUTPUT_DIR="${FETCH_PATH%/}"
            FETCH_OUTPUT_FILEPATH="$FETCH_OUTPUT_DIR/${FETCH_URL##*/}"
            ;;
        *)
            FETCH_OUTPUT_DIR="$(dirname "$FETCH_PATH")"
            FETCH_OUTPUT_FILEPATH="$FETCH_PATH"
    esac

    if [ -n "$FETCH_OUTPUT_FILEPATH" ] ; then
        if [ -f "$FETCH_OUTPUT_FILEPATH" ] ; then
            if [ -n "$FETCH_SHA256_EXPECTED" ] ; then
                if [ "$(sha256sum "$FETCH_OUTPUT_FILEPATH" | cut -d ' ' -f1)" = "$FETCH_SHA256_EXPECTED" ] ; then
                    success "$FETCH_OUTPUT_FILEPATH already have been fetched."
                    return 0
                fi
            fi
        fi

        if [ "$NOT_BUFFER" = 1 ] ; then
            FETCH_BUFFER_FILEPATH="$FETCH_OUTPUT_FILEPATH"
        else
            FETCH_UTS="$(date +%s)"

            FETCH_SHA="$(printf '%s\n' "$FETCH_URL:$$:$FETCH_UTS" | sha256sum | cut -d ' ' -f1)"

            FETCH_BUFFER_FILEPATH="$FETCH_OUTPUT_DIR/$FETCH_SHA.tmp"
        fi
    fi

    for FETCH_TOOL in curl wget http lynx aria2c axel
    do
        if command -v "$FETCH_TOOL" > /dev/null ; then
            break
        else
            unset FETCH_TOOL
        fi
    done

    if [ -z "$FETCH_TOOL" ] ; then
        abort 1 "no fetch tool found, please install one of curl wget http lynx aria2c axel, then try again."
    fi

    if [                -n "$FETCH_OUTPUT_DIR" ] ; then
        if [ !          -d "$FETCH_OUTPUT_DIR" ] ; then
            run install -d "$FETCH_OUTPUT_DIR" || return 1
        fi
    fi

    case $FETCH_TOOL in
        curl)
            CURL_OPTIONS="--fail --retry 20 --retry-delay 30 --location"

            if [ "$DUMP_HTTP" = 1 ] ; then
                CURL_OPTIONS="$CURL_OPTIONS --verbose"
            fi

            if [ -n "$SSL_CERT_FILE" ] ; then
                CURL_OPTIONS="$CURL_OPTIONS --cacert $SSL_CERT_FILE"
            fi

            run "curl $CURL_OPTIONS -o '$FETCH_BUFFER_FILEPATH' '$FETCH_URL'" ||
            run "curl $CURL_OPTIONS -o '$FETCH_BUFFER_FILEPATH' '$FETCH_URI'"
            ;;
        wget)
            run "wget --timeout=60 -O '$FETCH_BUFFER_FILEPATH' '$FETCH_URL'" ||
            run "wget --timeout=60 -O '$FETCH_BUFFER_FILEPATH' '$FETCH_URI'"
            ;;
        http)
            run "http --timeout=60 -o '$FETCH_BUFFER_FILEPATH' '$FETCH_URL'" ||
            run "http --timeout=60 -o '$FETCH_BUFFER_FILEPATH' '$FETCH_URI'"
            ;;
        lynx)
            run "lynx -source '$FETCH_URL' > '$FETCH_BUFFER_FILEPATH'" ||
            run "lynx -source '$FETCH_URI' > '$FETCH_BUFFER_FILEPATH'"
            ;;
        aria2c)
            run "aria2c -d '$FETCH_OUTPUT_DIR' -o '$FETCH_OUTPUT_FILENAME' '$FETCH_URL'" ||
            run "aria2c -d '$FETCH_OUTPUT_DIR' -o '$FETCH_OUTPUT_FILENAME' '$FETCH_URI'"
            ;;
        axel)
            run "axel -o '$FETCH_BUFFER_FILEPATH' '$FETCH_URL'" ||
            run "axel -o '$FETCH_BUFFER_FILEPATH' '$FETCH_URI'"
            ;;
        *)  abort 1 "wfetch() unimplementation: $FETCH_TOOL"
            ;;
    esac

    [ $? -eq 0 ] || return 1

    if [ -n "$FETCH_OUTPUT_FILEPATH" ] ; then
        if [ -n "$FETCH_SHA256_EXPECTED" ] ; then
            FETCH_SHA256_ACTUAL="$(sha256sum "$FETCH_BUFFER_FILEPATH" | cut -d ' ' -f1)"

            if [ "$FETCH_SHA256_ACTUAL" != "$FETCH_SHA256_EXPECTED" ] ; then
                abort 1 "sha256sum mismatch.\n    expect : $FETCH_SHA256_EXPECTED\n    actual : $FETCH_SHA256_ACTUAL\n"
            fi
        fi

        if [ "$NOT_BUFFER" != 1 ] ; then
            run mv "$FETCH_BUFFER_FILEPATH" "$FETCH_OUTPUT_FILEPATH"
        fi
    fi
}

filetype_from_url() {
    # remove query params
    URL="${1%%'?'*}"

    FNAME="${URL##*/}"

    case $FNAME in
        *.tar.gz|*.tgz)
            printf '%s\n' '.tgz'
            ;;
        *.tar.lz|*.tlz)
            printf '%s\n' '.tlz'
            ;;
        *.tar.xz|*.txz)
            printf '%s\n' '.txz'
            ;;
        *.tar.bz2|*.tbz2)
            printf '%s\n' '.tbz2'
            ;;
        *.*)printf '%s\n' ".${FNAME##*.}"
    esac
}

inspect_install_arguments() {
    unset PROFILE

    unset LOG_LEVEL

    unset BUILD_NJOBS

    unset ENABLE_LTO

    unset REQUEST_TO_KEEP_SESSION_DIR

    unset SPECIFIED_PACKAGE_LIST

    unset SESSION_DIR
    unset DOWNLOAD_DIR
    unset PACKAGE_INSTALL_DIR

    unset DUMP_ENV
    unset DUMP_HTTP

    unset VERBOSE_GMAKE

    unset DEBUG_CC
    unset DEBUG_LD

    while [ -n "$1" ]
    do
        case $1 in
            -x) set -x ;;
            -q) LOG_LEVEL=0 ;;
            -v) LOG_LEVEL=2

                DUMP_ENV=1
                DUMP_HTTP=1

                VERBOSE_GMAKE=1

                DEBUG_CC=1
                DEBUG_LD=1
                ;;
            -v-env)
                DUMP_ENV=1
                ;;
            -v-http)
                DUMP_HTTP=1
                ;;
            -v-gmake)
                VERBOSE_GMAKE=1
                ;;
            -v-cc)
                DEBUG_CC=1
                ;;
            -v-ld)
                DEBUG_LD=1
                ;;
            --profile=*)
                PROFILE="${1#*=}"
                ;;
            --session-dir=*)
                SESSION_DIR="${1#*=}"

                case $SESSION_DIR in
                    /*) ;;
                    *)  SESSION_DIR="$PWD/$SESSION_DIR"
                esac
                ;;
            --download-dir=*)
                DOWNLOAD_DIR="${1#*=}"

                case $DOWNLOAD_DIR in
                    /*) ;;
                    *)  DOWNLOAD_DIR="$PWD/$DOWNLOAD_DIR"
                esac
                ;;
            --prefix=*)
                PACKAGE_INSTALL_DIR="${1#*=}"

                case $PACKAGE_INSTALL_DIR in
                    /*) ;;
                    *)  PACKAGE_INSTALL_DIR="$PWD/$PACKAGE_INSTALL_DIR"
                esac
                ;;
            -j) shift
                isInteger "$1" || abort 1 "-j <N>, <N> must be an integer."
                BUILD_NJOBS="$1"
                ;;
            -K) REQUEST_TO_KEEP_SESSION_DIR=1 ;;

            -*) abort 1 "unrecognized option: $1"
                ;;
            *)  SPECIFIED_PACKAGE_LIST="$SPECIFIED_PACKAGE_LIST $1"
        esac
        shift
    done

    #########################################################################################

    : ${PROFILE:=release}
    : ${ENABLE_LTO:=1}

    : ${SESSION_DIR:="$HOME/.xbuilder/run/$$"}
    : ${DOWNLOAD_DIR:="$HOME/.xbuilder/downloads"}
    : ${PACKAGE_INSTALL_DIR:="$HOME/.xbuilder/installed/perl"}

    #########################################################################################

    AUX_INSTALL_DIR="$SESSION_DIR/auxroot"
    AUX_INCLUDE_DIR="$AUX_INSTALL_DIR/include"
    AUX_LIBRARY_DIR="$AUX_INSTALL_DIR/lib"

    #########################################################################################

    NATIVE_PLATFORM_TYPE="$(uname -s | tr A-Z a-z)"
    NATIVE_PLATFORM_ARCH="$(uname -m)"

    #########################################################################################

    if [ -z "$BUILD_NJOBS" ] ; then
        if [ "$NATIVE_PLATFORM_TYPE" = darwin ] ; then
            NATIVE_PLATFORM_NCPU="$(sysctl -n machdep.cpu.thread_count)"
        else
            NATIVE_PLATFORM_NCPU="$(nproc)"
        fi

        BUILD_NJOBS="$NATIVE_PLATFORM_NCPU"
    fi

    #########################################################################################

    if [ "$LOG_LEVEL" = 0 ] ; then
        exec 1>/dev/null
        exec 2>&1
    else
        if [ -z "$LOG_LEVEL" ] ; then
            LOG_LEVEL=1
        fi
    fi

    #########################################################################################

    if [ -z "$TAR" ] ; then
        TAR="$(command -v bsdtar || command -v gtar || command -v tar)" || abort 1 "none of bsdtar, gtar, tar command was found."
    fi

    if [ -z "$GMAKE" ] ; then
        GMAKE="$(command -v gmake || command -v make)" || abort 1 "command not found: gmake"
    fi

    #########################################################################################

    unset CC_ARGS
    unset PP_ARGS
    unset LD_ARGS

    if [ "$NATIVE_PLATFORM_TYPE" = darwin ] ; then
        [ -z "$CC"      ] &&      CC="$(xcrun --sdk macosx --find clang)"
        [ -z "$CXX"     ] &&     CXX="$(xcrun --sdk macosx --find clang++)"
        [ -z "$AS"      ] &&      AS="$(xcrun --sdk macosx --find as)"
        [ -z "$LD"      ] &&      LD="$(xcrun --sdk macosx --find ld)"
        [ -z "$AR"      ] &&      AR="$(xcrun --sdk macosx --find ar)"
        [ -z "$RANLIB"  ] &&  RANLIB="$(xcrun --sdk macosx --find ranlib)"
        [ -z "$SYSROOT" ] && SYSROOT="$(xcrun --sdk macosx --show-sdk-path)"

        [ -z "$MACOSX_DEPLOYMENT_TARGET" ] && {
            NATIVE_PLATFORM_VERS="$(sw_vers -productVersion)"
            MACOSX_DEPLOYMENT_TARGET="${NATIVE_PLATFORM_VERS%.*}"
        }

        install -d "$SESSION_DIR"

        WRAPPER_CC="$SESSION_DIR/wrapper-cc"

        tee "$WRAPPER_CC" <<EOF
#!/bin/sh
exec $CC -isysroot $SYSROOT -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET -arch $NATIVE_PLATFORM_ARCH -Qunused-arguments "\$@"
EOF
        chmod +x "$WRAPPER_CC"
        export CC="$WRAPPER_CC"
    else
        [ -z "$CC" ] && {
             CC="$(command -v cc  || command -v clang   || command -v gcc)" || abort 1 "C Compiler not found."
        }

        [ -z "$CXX" ] && {
            CXX="$(command -v c++ || command -v clang++ || command -v g++)" || abort 1 "C++ Compiler not found."
        }

        [ -z "$AS" ] && {
            AS="$(command -v as)" || abort 1 "command not found: as"
        }

        [ -z "$LD" ] && {
            LD="$(command -v ld)" || abort 1 "command not found: ld"
        }

        [ -z "$AR" ] && {
            AR="$(command -v ar)" || abort 1 "command not found: ar"
        }

        [ -z "$RANLIB" ] && {
            RANLIB="$(command -v ranlib)" || abort 1 "command not found: ranlib"
        }

        # https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html
        LD_ARGS='-Wl,--as-needed'
    fi

    #########################################################################################

    CC_ARGS='-fPIC'

    CPP="$CC -E"

    #########################################################################################

    [ "$DEBUG_CC" = 1 ] && CC_ARGS="$CC_ARGS -v"
    [ "$DEBUG_LD" = 1 ] && LD_ARGS="$LD_ARGS -Wl,-v"

    case $PROFILE in
        debug)
            CC_ARGS="$CC_ARGS -O0 -g"
            ;;
        release)
            CC_ARGS="$CC_ARGS -Os"

            if [ "$ENABLE_LTO" = 1 ] ; then
                LD_ARGS="$LD_ARGS -flto"
            fi

            if [ "$NATIVE_PLATFORM_TYPE" = darwin ] ; then
                LD_ARGS="$LD_ARGS -Wl,-S"
            else
                LD_ARGS="$LD_ARGS -Wl,-s"
            fi
    esac

    case $NATIVE_PLATFORM_TYPE in
         netbsd) LD_ARGS="$LD_ARGS -lpthread" ;;
        openbsd) LD_ARGS="$LD_ARGS -lpthread" ;;
    esac

    #########################################################################################

      CFLAGS="$CC_ARGS   $CFLAGS"
    CXXFLAGS="$CC_ARGS $CXXFLAGS"
    CPPFLAGS="$PP_ARGS $CPPFLAGS"
     LDFLAGS="$LD_ARGS  $LDFLAGS"

    #########################################################################################

    for TOOL in CC CXX CPP AS AR RANLIB LD SYSROOT CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
    do
        export "${TOOL}"
    done

    #########################################################################################

    unset PKG_CONFIG_LIBDIR
    unset PKG_CONFIG_PATH
    unset PKG_CONFIG
    unset ACLOCAL_PATH

    unset LIBS

    # autoreconf --help

    unset AUTOCONF
    unset AUTOHEADER
    unset AUTOM4TE
    unset AUTOMAKE
    unset AUTOPOINT
    unset ACLOCAL
    unset GTKDOCIZE
    unset INTLTOOLIZE
    unset LIBTOOLIZE
    unset M4
    unset MAKE

    # https://stackoverflow.com/questions/18476490/what-is-purpose-of-target-arch-variable-in-makefiles
    unset TARGET_ARCH

    # https://keith.github.io/xcode-man-pages/xcrun.1.html
    unset SDKROOT

    unset PERL5LIB
}

configure() {
    run ./configure "--prefix=$PACKAGE_INSTALL_DIR" "$@"
    run "$GMAKE" "--jobs=$BUILD_NJOBS"
    run "$GMAKE" install
}

install_the_given_package() {
    [ -z "$1" ] && abort 1 "install_the_given_package <PACKAGE-NAME> , <PACKAGE-NAME> is unspecified."

    unset PACKAGE_SRC_URL
    unset PACKAGE_SRC_URI
    unset PACKAGE_SRC_SHA
    unset PACKAGE_DEP_PKG
    unset PACKAGE_DOPATCH
    unset PACKAGE_INSTALL
    unset PACKAGE_DOTWEAK

    package_info_$1

    #########################################################################################

    for PACKAGE_DEPENDENCY in $PACKAGE_DEP_PKG
    do
        (install_the_given_package "$PACKAGE_DEPENDENCY")
    done

    #########################################################################################

    printf '\n%b\n' "${COLOR_PURPLE}=>> $ARG0: install package : $1${COLOR_OFF}"

    #########################################################################################

    if [ "$1" != perl ] ; then
        PACKAGE_INSTALL_DIR="$AUX_INSTALL_DIR"
    fi

    #########################################################################################

    if [ -f "$PACKAGE_INSTALL_DIR/$1.yml" ] ; then
        note "package '$1' already has been installed, skipped."
        return 0
    fi

    #########################################################################################

    PACKAGE_SRC_FILETYPE="$(filetype_from_url "$PACKAGE_SRC_URL")"
    PACKAGE_SRC_FILENAME="$PACKAGE_SRC_SHA$PACKAGE_SRC_FILETYPE"
    PACKAGE_SRC_FILEPATH="$DOWNLOAD_DIR/$PACKAGE_SRC_FILENAME"

    #########################################################################################

    wfetch "$PACKAGE_SRC_URL" --uri="$PACKAGE_SRC_URI" --sha256="$PACKAGE_SRC_SHA" -o "$PACKAGE_SRC_FILEPATH"

    #########################################################################################

    PACKAGE_WORKING_DIR="$SESSION_DIR/$1"

    #########################################################################################

    run install -d "$PACKAGE_WORKING_DIR/src"
    run cd         "$PACKAGE_WORKING_DIR/src"

    #########################################################################################

    run "$TAR" xf "$PACKAGE_SRC_FILEPATH" --strip-components=1 --no-same-owner

    #########################################################################################

    if [ -n  "$PACKAGE_DOPATCH" ] ; then
        eval "$PACKAGE_DOPATCH"
    fi

    #########################################################################################

    if [ "$DUMP_ENV" = 1 ] ; then
        run export -p
    fi

    #########################################################################################

    if [ -n  "$PACKAGE_INSTALL" ] ; then
        eval "$PACKAGE_INSTALL"
    else
        abort 1 "PACKAGE_INSTALL variable is not set for package '$1'"
    fi

    #########################################################################################

    run cd "$PACKAGE_INSTALL_DIR"

    #########################################################################################

    if [ -n  "$PACKAGE_DOTWEAK" ] ; then
        eval "$PACKAGE_DOTWEAK"
    fi

    #########################################################################################

    run cd "$PACKAGE_INSTALL_DIR"

    #########################################################################################

    PACKAGE_INSTALL_UTS="$(date +%s)"

    cat > "$1.yml" <<EOF
src-url: $PACKAGE_SRC_URL
src-uri: $PACKAGE_SRC_URI
src-sha: $PACKAGE_SRC_SHA
dep-pkg: $PACKAGE_DEP_PKG
install: $PACKAGE_INSTALL
builtat: $PACKAGE_INSTALL_UTS
prefix:  $PACKAGE_INSTALL_DIR
EOF

    #########################################################################################

    cat > toolchain.txt <<EOF
     CC='$CC'
    CXX='$CXX'
     AS='$AS'
     LD='$LD'
     AR='$AR'
 RANLIB='$RANLIB'
SYSROOT='$SYSROOT'
PROFILE='$PROFILE'
 CFLAGS='$CFLAGS'
LDFLAGS='$LDFLAGS'
EOF
}

package_info_perl() {
    PACKAGE_SRC_URL='https://www.cpan.org/src/5.0/perl-5.42.2.tar.xz'
    PACKAGE_SRC_URI='https://distfiles.macports.org/perl5.42/perl-5.42.2.tar.xz'
    PACKAGE_SRC_SHA='0a585eeb9e363c0f80482ddb3571625250c2c86aeb408853e8ea50805cfb14bb'
    PACKAGE_CONFIGURE_ARGS='-des -Dmake=gmake -Duselargefiles -Duseshrplib=false -Dusethreads -Dusenm=false -Dusedl=true -Duserelocatableinc=true -Dman1dir=none -Dman3dir=none -Dprefix="$PACKAGE_INSTALL_DIR" -Dcc="$CC" -Dar="$AR"'

    if [ "$NATIVE_PLATFORM_TYPE" = darwin ] ; then
        PACKAGE_CONFIGURE_ARGS="$PACKAGE_CONFIGURE_ARGS -Dccflags=\"\$CFLAGS\" -Dldflags=\"\$LDFLAGS\" -Dcppflags=\"\$CPPFLAGS\""
    else
        PACKAGE_CONFIGURE_ARGS="$PACKAGE_CONFIGURE_ARGS -Accflags=\"\$CFLAGS\" -Aldflags=\"\$LDFLAGS\" -Acppflags=\"\$CPPFLAGS\""

        if [ "$NATIVE_PLATFORM_TYPE" = linux ] ; then
            # https://github.com/Perl/perl5/issues/22913
            PACKAGE_CONFIGURE_ARGS="$PACKAGE_CONFIGURE_ARGS -Ud_procselfexe"
        fi
    fi

    PACKAGE_INSTALL='run ./Configure "$PACKAGE_CONFIGURE_ARGS" && run "$GMAKE" "--jobs=$BUILD_NJOBS" && run "$GMAKE" install'
}

help() {
    printf '%b\n' "\
${COLOR_GREEN}A self-contained and relocatable Perl distribution builder.${COLOR_OFF}

${COLOR_GREEN}$ARG0 --help${COLOR_OFF}
${COLOR_GREEN}$ARG0 -h${COLOR_OFF}
    show help of this command.

${COLOR_GREEN}$ARG0 version${COLOR_OFF}
    show version of perl.

${COLOR_GREEN}$ARG0 info${COLOR_OFF}
    show information of perl.

${COLOR_GREEN}$ARG0 install [OPTIONS]${COLOR_OFF}
    install the perl package.

    Influential environment variables: TAR, GMAKE, CC, CXX, AS, LD, AR, RANLIB, CFLAGS, CXXFLAGS, CPPFLAGS, LDFLAGS

    OPTIONS:
        ${COLOR_BLUE}--prefix=<DIR>${COLOR_OFF}
            specify where to be installed into.

        ${COLOR_BLUE}--session-dir=<DIR>${COLOR_OFF}
            specify the session directory.

        ${COLOR_BLUE}--download-dir=<DIR>${COLOR_OFF}
            specify the download directory.

        ${COLOR_BLUE}--profile=<debug|release>${COLOR_OFF}
            specify the build profile.

            debug:
                  CFLAGS: -O0 -g
                CXXFLAGS: -O0 -g

            release:
                  CFLAGS: -Os
                CXXFLAGS: -Os
                CPPFLAGS: -DNDEBUG
                 LDFLAGS: -flto -Wl,-s

        ${COLOR_BLUE}-j <N>${COLOR_OFF}
            specify the number of jobs you can run in parallel.

        ${COLOR_BLUE}-K${COLOR_OFF}
            keep the session directory even if this packages are successfully installed.

        ${COLOR_BLUE}-q${COLOR_OFF}
            silent mode. no any messages will be output to terminal.

        ${COLOR_BLUE}-v${COLOR_OFF}
            verbose mode. many messages will be output to terminal.

        ${COLOR_BLUE}-x${COLOR_OFF}
            debug current running shell.

        ${COLOR_BLUE}-v-env${COLOR_OFF}
            show all environment variables before starting to build.

        ${COLOR_BLUE}-v-http${COLOR_OFF}
            show http request/response.

        ${COLOR_BLUE}-v-gmake${COLOR_OFF}
            pass V=1 argument to gmake command.

        ${COLOR_BLUE}-v-cc${COLOR_OFF}
            pass -v argument to the C/C++ compiler.

        ${COLOR_BLUE}-v-ld${COLOR_OFF}
            pass -v argument to the linker.
"
}

case $1 in
    ''|--help|-h)
        help
        ;;
    version)
        unset PACKAGE_SRC_URL

        package_info_perl

        PACKAGE_SRC_FILENAME="${PACKAGE_SRC_URI##*/}"
        PACKAGE_SRC_FILENAME_PREFIX="${PACKAGE_SRC_FILENAME%.tar.*}"
        PACKAGE_VERSION="${PACKAGE_SRC_FILENAME_PREFIX##*-}"

        printf '%s\n' "$PACKAGE_VERSION"
        ;;
    info)
        unset PACKAGE_SRC_URL
        unset PACKAGE_SRC_URI
        unset PACKAGE_SRC_SHA
        unset PACKAGE_DEP_PKG
        unset PACKAGE_DOPATCH
        unset PACKAGE_INSTALL
        unset PACKAGE_DOTWEAK

        package_info_perl

        cat <<EOF
src-url: $PACKAGE_SRC_URL
src-sha: $PACKAGE_SRC_SHA
EOF
        ;;
    install)
        shift

        inspect_install_arguments "$@"

        install_the_given_package perl

        if [ "$REQUEST_TO_KEEP_SESSION_DIR" != 1 ] ; then
            rm -rf "$SESSION_DIR"
        fi
        ;;
    *)  abort 1 "unrecognized argument: $1"
esac
