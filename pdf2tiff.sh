#!/bin/bash
#
# Author: rasan@nyu.edu

PDF_FILE=$1

echo $PDF_FILE

NUM_PAGES=`pdfinfo "${PDF_FILE}" | grep Pages | sed 's/[^0-9]*//'`

echo $NUM_PAGES

pdfseparate "$PDF_FILE" page-%d.pdf

page_num=1

get_file_name ()
{
	printf 'out-%06d.tif' $page_num
}

for i in `seq 1 $NUM_PAGES`; do
	echo $i
	gs -q -dNOPAUSE -sDEVICE=tiff24nc -dBATCH -r300 \
		-sOutputFile=page-$i.tif page-$i.pdf
	if [ $i -gt 1 -a $i -lt $NUM_PAGES ]; then
		convert page-$i.tif -crop 50%x100% +repage \
			-colorspace sRGB -type TrueColor \
			-compress lzw half-%d.tif
		mv half-0.tif `get_file_name $page_num`
		page_num=$((page_num+1))
		mv half-1.tif `get_file_name $page_num`
	else
		convert page-$i.tif -compress lzw `get_file_name $page_num`
	fi
	page_num=$((page_num+1))
done

