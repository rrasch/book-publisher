#!/bin/bash

gs -sDEVICE=pdfwrite \
	-sColorConversionStrategy=Gray \
	-dProcessColorModel=/DeviceGray \
	-dCompatibilityLevel=1.4 \
	-dPDFSETTINGS=/screen \
	-dNOPAUSE -dQUIET -dBATCH \
	-o "$2" "$1"

