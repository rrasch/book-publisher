#!/bin/bash

WWW_DIR="$HOME/maps"

RSTAR_DIR=`echo /content/prod/rstar/content/*/aco | tr ' ' ':'`

./gen-kml.pl -w $WWW_DIR -r $RSTAR_DIR > $WWW_DIR/maps.kml

