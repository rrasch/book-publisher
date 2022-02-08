#!/bin/bash

WWW_DIR="$HOME/maps"

if [ $# -ne 1 ]; then
	echo "Usage: $0 <collection>"
	exit
fi

COLL=$1

RSTAR_DIR=`echo /content/prod/rstar/content/*/$COLL | tr ' ' ':'`

./gen-kml.pl \
	-g \
	-c red \
	-w $WWW_DIR \
	-r $RSTAR_DIR > ${WWW_DIR}/${COLL}.kml

