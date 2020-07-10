#!/bin/bash

# set -e

ROOT_DIR=/content/prod/rstar/content

for rstar_dir in `find $ROOT_DIR -maxdepth 2 -name awdl`
do
    tmp=${rstar_dir%/awdl}
    partner=${tmp##*/}
    for i in `ls $rstar_dir/wip/se`; do
        digid=${i##*/}
        coord_file="${rstar_dir}/wip/se/${digid}/aux/${digid}_geo_coord.json"
        if [ ! -f "$coord_file" ]; then
            echo $digid
        fi
    done
done

