#!/bin/bash
export OAR_JOB_ID=$1
export PATH=$PATH:/run/current-system/sw/bin:/run/wrappers/bin
(
echo Enter BEBIDA prolog

printenv
id

if [[ "$OAR_JOB_NAME" == BEBIDA_NOOP* ]]
then
    echo BEBIDA_NOOP is set. Do not stop the kubernetes agent
    exit 0
fi

for node in $(oarstat -J -j "$OAR_JOB_ID" -p | jq ".[\"$OAR_JOB_ID\"][] | .network_address" -r)
do
  echo == Removing node $node
  oardodo kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml drain --force --grace-period=5 --ignore-daemonsets --delete-emptydir-data --timeout=15s $node
  echo == Removed node $node
done
) > /tmp/oar-${OAR_JOB_ID}-prolog-logs 2> /tmp/oar-${OAR_JOB_ID}-prolog-logs

