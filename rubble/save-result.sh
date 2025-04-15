#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: bash save-result.sh shard_num suffix"
    exit
fi

shard_num=$1
suffix=$2

# add output directory
output_dir="/users/CS0522/outputs"

cp dstat.csv ${output_dir}/dstat-${suffix}.csv
cp iostat.out ${output_dir}/iostat-${suffix}.out
cp pids.out ${output_dir}/pids-${suffix}.out
cp top.out ${output_dir}/top-${suffix}.out
cp nethogs.out ${output_dir}/nethogs-${suffix}.out

for (( i=0; i<$shard_num; i++ ))
do
    cp shard-${i}.out ${output_dir}/shard-${i}-${suffix}.out
    cp /mnt/data/db/shard-${i}/db/LOG ${output_dir}/LOG-shard-${i}-${suffix}
done
