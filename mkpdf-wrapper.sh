#!/bin/bash
#
# Author: Rasan Rasch <rasan@nyu.edu>

trap "" HUP

# set -e

# current date/time, e.g. 2010-07-13-20-14-59
NOW=$(date +"%Y-%m-%d-%H-%M-%S")

# log both stdout/stderr to this file
#LOGFILE=logs/ifa-egypt-pdf-$NOW.log
LOGFILE=logs/ifa-egypt-pdf.log

LOGDIR=`dirname $LOGFILE`
[ ! -d "$LOGDIR" ] && mkdir -p $LOGDIR

exec >> $LOGFILE 2>&1

touch results.txt

if [ $# -gt 0 ]; then
	PUBS=$*
else
	PUBS=`ls /content/prod/rstar/content/ifa/egypt/xip | sort`
fi

for PUB in $PUBS
do
	if grep -q $PUB results.txt; then
		echo "Skipping $PUB, already processed."
		continue
	fi
	echo Processing $PUB
	time ./mkpdf.pl $PUB
	RETVAL=$?
	if [ $RETVAL -eq 0 ]; then
		STATUS=PASS
	else
		STATUS=FAIL
	fi
	echo "$PUB: $STATUS" >> results.txt
	sleep 30
done

