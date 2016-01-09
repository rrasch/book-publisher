#!/bin/bash
#
# Wrapper script for book-import.pl
#
# Author: Rasan Rasch <rasan@nyu.edu>

# Set environment variable MAILTO with your email address
# to receive fail notification
MAILTO=${MAILTO:-$USER}

trap "" HUP
trap "echo 'Import Failed' | mail -s 'Import Failed' $MAILTO" ERR

set -e

CFG_FILE=/path/to/MyConfig.pm

WIP_DIR="$(grep rstar_dir $CFG_FILE | grep -v '#' | cut -d\" -f2)/wip/ie"

# current date/time, e.g. 2010-07-13-20-14-59
NOW=$(date +"%Y-%m-%d-%H-%M-%S")

# log both stdout/stderr to this file
# LOGFILE=logs/import-$NOW.log
LOGFILE=logs/import.log

LOGDIR=`dirname $LOGFILE`
[ ! -d "$LOGDIR" ] && mkdir -p $LOGDIR

exec >> $LOGFILE 2>&1

touch results.txt

if [ $# -gt 0 ]; then
	BOOKS=$*
else
	BOOKS=`ls $WIP_DIR | sort`
fi

for BOOK in $BOOKS
do
	if grep -q $BOOK results.txt; then
		echo "Skipping $BOOK, already processed."
		continue
	fi
	echo Processing $BOOK
	time ./book-import.pl $BOOK
	RETVAL=$?
	if [ $RETVAL -eq 0 ]; then
		STATUS=PASS
	else
		STATUS=FAIL
	fi
	echo "$BOOK: $STATUS" >> results.txt
	sleep 60
done

