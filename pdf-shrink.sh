#!/bin/bash

# Shrink size of PDF by resampling images to 72pi.

while getopts "g" opt; do
	case $opt in
		g)
			OPTS="-sColorConversionStrategy=Gray"
			OPTS="$OPTS -dProcessColorModel=/DeviceGray"
			;;
	esac
done
shift $((OPTIND - 1))

gs -sDEVICE=pdfwrite $OPTS \
	-dCompatibilityLevel=1.4 \
	-dPDFSETTINGS=/screen \
	-dNOPAUSE -dQUIET -dBATCH \
	-o "$2" "$1"

