#!/bin/bash

ROOT_DIR=/content/prod/rstar/content

tmpdir=${TMPDIR-/tmp}/awdl-kml.$$
mkdir $tmpdir || exit 1
trap "rm -rf $tmpdir; exit" 0 1 2 3 15

script=`readlink -m $0`
bindir=${script%/*}
# echo $bindir

for rstar_dir in `find $ROOT_DIR -maxdepth 2 -name awdl`
do
	tmp=${rstar_dir%/awdl}
	partner=${tmp##*/}
# 	echo $partner
	kml_file="$tmpdir/$partner.kml"
	kml_file="$partner.kml"
	echo "$bindir/gen-kml.pl -r $rstar_dir > $kml_file"
done

# java -jar /usr/share/java/saxon.jar out.kml merge.xslt with=out2.kml dontmerge=Placemark | xmllint --format - > combined.xml


