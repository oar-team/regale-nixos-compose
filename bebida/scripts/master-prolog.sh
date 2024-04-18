#!/usr/bin/env bash

set -x
set -e

(
export PATH=/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export KUBECONFIG=/etc/bebida/kubeconfig.yaml

printenv

if [[ "$SLURM_JOB_NAME" == BEBIDA_NOOP* ]]
then
    echo BEBIDA_NOOP is set. Do not stop the kubernetes agent
    exit 0
fi

export SLURM_NODELIST=$SLURM_JOB_NODELIST
for node in $(scontrol show hostnames)
do
        kubectl drain --force --grace-period=5 --ignore-daemonsets --delete-emptydir-data --insecure-skip-tls-verify $node
done
) > /etc/bebida/log/${SLURM_JOB_ID}-prolog-logs 2> /etc/bebida/log/${SLURM_JOB_ID}-prolog-logs
