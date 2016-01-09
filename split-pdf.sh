#!/bin/bash
#
# Split pdf into images
#
# Author: Rasan Rasch <rasan@nyu.edu>

BOOKID=isaw_ciaa000001

pdfimages -j $BOOKID.pdf out

i=0
declare -a files
for f in out*.jpg; do
	jpg=`printf "${BOOKID}_n%06d_s.jpg" $((i+1))`
	jp2=${jpg/_s.jpg/_d.jp2}
	files[i]=$jpg
	convert $f -resize x2000 $jpg
	rm -f $f
	convert $jpg $jp2
	i=$((i+1))
done

NUM_FILES=$i
echo Number of files: $NUM_FILES

BORDER_WIDTH=0

CONVERT_ARGS="-background white -splice ${BORDER_WIDTH}x0 +append -crop +${BORDER_WIDTH}+0"

for i in 0 $NUM_FILES-1; do
	OUTFILE=`printf "${BOOKID}_2up_%04d_%04d.jp2" $((i+1)) $((i+1))`
	jpg=${files[$i]}
	cp ${jpg/_s.jpg/_d.jp2} $OUTFILE
done

for ((i = 1 ; i < NUM_FILES -1 ; i += 2)); do
	OUTFILE=`printf "${BOOKID}_2up_%04d_%04d.jp2" $((i+1)) $((i+2))`
	convert ${files[$i]} ${files[$i+1]} $CONVERT_ARGS $OUTFILE
done

