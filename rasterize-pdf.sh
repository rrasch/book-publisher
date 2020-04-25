#!/bin/bash

set -eux

if [ "x$1" = "x" -o "x$2" = "x" ]; then
    echo Usage: `basename "$0"` "<input.pdf>" "<output.pdf>" >&2
    exit 1
fi

TMPFILE=$(mktemp)

# gs -sDEVICE=ps2write -dNOCACHE -sOutputFile=- -q -dbatch \
#    -dNOPAUSE -dQUIET "$1" -c quit | ps2pdf - "$2"

# gs -dNoOutputFonts -sDEVICE=pdfwrite -o "$2" "$1"

gs -q -sDEVICE=tiffg4 -dNOPAUSE -dBATCH -r300 -o "$TMPFILE" "$1"
tiff2pdf -z -f -F -pletter -o "$2" "$TMPFILE"
rm -f $TMPFILE
unset-gvfs.sh "$2"

