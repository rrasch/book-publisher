#!/bin/bash

set -eu

if [ $# -ne 1 ]; then
    echo -e "\nUsage: $0 <git url>\n"
    exit 1
fi

URL=$1

trap 'rm -rf "$tmpdir"; exit' EXIT HUP INT QUIT TERM

tmpdir=$(mktemp -d) || exit 1

cd $tmpdir

git clone --quiet --bare "${URL}.git" repo

cd repo

commit_id=$(git log -n 1 --pretty=format:"%h" | tail -n 1)

echo $commit_id

