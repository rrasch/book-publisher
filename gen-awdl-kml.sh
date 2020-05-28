#!/bin/bash

ROOT_DIR=/content/prod/rstar/content

set -e

tmpdir=${TMPDIR-/tmp}/awdl-kml.$$
mkdir $tmpdir || exit 1
trap "rm -rf $tmpdir; exit" 0 1 2 3 15

script=`readlink -m $0`
bindir=${script%/*}

for rstar_dir in `find $ROOT_DIR -maxdepth 2 -name awdl`
do
	tmp=${rstar_dir%/awdl}
	partner=${tmp##*/}
	kml_file="$tmpdir/$partner.kml"
	$bindir/gen-kml.pl -r $rstar_dir > $kml_file
	[ ! -s "$kml_file" ] && rm -f $kml_file
done

$bindir/merge-kml.py $tmpdir/*.kml | xmllint --format - > awdl.kml


