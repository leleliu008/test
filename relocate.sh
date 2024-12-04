#!/bin/sh

set -e

D="$(dirname "$1")"

cd "$D"

SYSROOT="$PWD/glibc/lib"
DYNAMIC_LOADER="$SYSROOT/ld-linux-x86-64.so.2"

for d in binutils
do
    fs="$(find "$d" -type f)"

    export IFS='
'

    for f in $fs
    do
        [ -f "$f" ] || continue

        FILE_MAGIC="$(./xxd -u -p -l 4 "$f")"

        # http://www.sco.com/developers/gabi/latest/ch4.eheader.html
        if [ "$FILE_MAGIC" = 7F454C46 ] ; then
            echo "ELF file: $f"

            PT_INTERP="$(./patchelf --print-interpreter "$f" 2>/dev/null || true)"

            if [ -n "$PT_INTERP" ] ; then
                ./patchelf --set-interpreter "$DYNAMIC_LOADER" "$f"
            fi

            DT_NEEDED="$(./patchelf --print-needed "$f" || true)"

            if [ -n "$DT_NEEDED" ] ; then
                ./patchelf --set-rpath "\$ORIGIN/../lib:$SYSROOT" "$f"
            fi
        fi
    done

    unset IFS
done
