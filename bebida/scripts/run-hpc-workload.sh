#!/usr/bin/env bash

set -e
set -x
set -u

SIZE=$1
RESULTS_DIR=$2
SPARK_APP=${3:-/etc/demo/spark-pi.yaml}

export ESPHOME=$(dirname $(dirname $(realpath $(which mkjobmix))))

EXPE_DIR=expe-$(date --iso-8601=minutes | tr ':' '-' | tr '+' '-')
export ESPSCRATCH=/users/user1/$EXPE_DIR
mkdir -p $ESPSCRATCH/logs
mkdir -p $ESPSCRATCH/jobmix
cd $ESPSCRATCH/jobmix

mkjobmix -s $SIZE -b OAR

chmod a+rwx ./*

cd ..

chmod -R 777 $ESPSCRATCH

# Cleanup OAR before start
oardel $(oarstat -J | jq '.[] | .id') || true
until [[ $(oarstat -J) == '{}' ]]
do
  echo Waiting for remaining jobs to be killed...
  sleep 1
done

# Reset Bebida Shaker to be sure we are on a clean state
systemctl restart bebida-shaker.service

get_result() {
  set +e
  echo "=== Kill HPC workflow submission"
  kill $PID
  echo "\n=== Copy results from $ESPSCRATCH to $RESULTS_DIR"
  mkdir $RESULTS_DIR/$EXPE_DIR
  cp -r $ESPSCRATCH/* $RESULTS_DIR/$EXPE_DIR
  echo === Get all history and logs
  # FIXME Should be enough for this year ^^
  oarstat --gantt "2024-01-01 00:00:00, 2025-01-01 00:00:00" -Jf > $RESULTS_DIR/$EXPE_DIR/oar-jobs.json
  k3s kubectl get events -o json > $RESULTS_DIR/$EXPE_DIR/k8s-events.json
  # Copy this script
  cp "${BASH_SOURCE[0]}" $RESULTS_DIR/$EXPE_DIR/expe-script.sh
  journalctl -u bebida-shaker.service > $RESULTS_DIR/$EXPE_DIR/shaker.log
  echo === Experiment done! 
  echo Results are located here:
  echo $RESULTS_DIR/$EXPE_DIR
}

trap get_result EXIT

k3s kubectl apply -f /etc/demo/spark-setup.yaml

# use -T 10 as runesp parameter to increase the load
su - user1 -c "export ESPHOME=$ESPHOME; export ESPSCRATCH=$ESPSCRATCH; runesp -v -T 10 -b OAR" &
PID=$!

# Put eventLogs in the user1 home result dir
SPARK_APP_TEMPLATED=$ESPSCRATCH/spark-app.yaml
sed s/%EXPE_DIR%/$EXPE_DIR/g  $SPARK_APP > $SPARK_APP_TEMPLATED

# Cleanup spark app
k3s kubectl delete -f $SPARK_APP_TEMPLATED || true

for run in $(seq 5)
do
    k3s kubectl apply -f $SPARK_APP_TEMPLATED
    k3s kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/spark-app-pi --timeout=3600s
    k3s kubectl get pod spark-app-pi -o json > $ESPSCRATCH/spark-app-pi-$run-pod.json
    k3s kubectl logs spark-app-pi > $ESPSCRATCH/spark-app-pi-$run-log.txt
    k3s kubectl delete -f $SPARK_APP_TEMPLATED
    sleep 5
done
echo Done!

