#!/bin/bash
#
# Author: rasan@nyu.edu

set -eu

GS="/usr/local/bin/gs"
if [ ! -x "$GS" ]; then
	GS=`command -v gs`
fi

echo "GS: $GS"

PDF_FILE=$1

echo "FILE: $PDF_FILE"

BASENAME=$(basename -- "$PDF_FILE")
BASENAME=${BASENAME%.*}
BASENAME=${BASENAME//[^[:alnum:]_-]/}

echo "BASENAME: $BASENAME"

read -r w h <<< `pdfinfo "${PDF_FILE}" | grep Page.size | awk '{print $3, $5}'`

echo "HEIGHT: $h"
echo "WIDTH: $w"

NUM_PAGES=`pdfinfo "${PDF_FILE}" | grep Pages | sed 's/[^0-9]*//'`

echo "NUM PAGES: $NUM_PAGES"

echo "Splitting pdf using pdfseparate"
pdfseparate "$PDF_FILE" page-%d.pdf

get_file_name ()
{
	local page_no=$1
	printf '%s-%06d.tif' $BASENAME $page_no
}

page_num=1

for i in `seq 1 $NUM_PAGES`; do
	echo "Processing page $i"
	$GS -q -dNOPAUSE -sDEVICE=tiff24nc -dBATCH -r300 \
		-sOutputFile=page-$i.tif page-$i.pdf
	if [ $w -gt $h -a $i -gt 1 -a $i -lt $NUM_PAGES ]; then
		convert page-$i.tif -crop 50%x100% +repage \
			-colorspace sRGB -type TrueColor \
			-compress lzw half-%d.tif
		mv half-0.tif `get_file_name $page_num`
		page_num=$((page_num+1))
		mv half-1.tif `get_file_name $page_num`
	else
		convert page-$i.tif -compress lzw `get_file_name $page_num`
	fi
	rm -v page-$i.pdf page-$i.tif
	page_num=$((page_num+1))
done

