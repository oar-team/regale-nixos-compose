#!/usr/bin/env bash

set -e
set -x
set -u

RESULT_DIR=$1

SCRIPT_PATH=$(dirname ${BASH_SOURCE[0]})

for iteration in $(seq 30)
do
    for heuristic in punch none deadline nohpc refill
    do
        $SCRIPT_PATH/run-hpc-workload.sh 288 $RESULT_DIR $SCRIPT_PATH/spark-pi.yaml $heuristic 4
    done
done
echo All experiment done!
