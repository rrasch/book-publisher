#!/bin/bash
#
# Author: rasan@nyu.edu

PDF_FILE=$1

echo $PDF_FILE

NUM_PAGES=`pdfinfo "${PDF_FILE}" | grep Pages | sed 's/[^0-9]*//'`

echo $NUM_PAGES

pdfseparate "$PDF_FILE" page-%d.pdf

page_num=1
for i in `seq 1 $NUM_PAGES`; do
	echo $i
	gs -q -dNOPAUSE -sDEVICE=tiff24nc -dBATCH \
		-sOutputFile=page-$i.tif page-$i.pdf
	if [ $i -gt 1 -a $i -lt $NUM_PAGES ]; then
		convert page-$i.tif -crop 50%x100% +repage half-%d.tif
		mv half-0.tif out-$page_num.tif
		page_num=$((page_num+1))
		mv half-1.tif out-$page_num.tif
	else
		mv page-$i.tif out-$page_num.tif
	fi
	page_num=$((page_num+1))
done

