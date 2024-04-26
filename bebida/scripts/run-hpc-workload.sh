#!/usr/bin/env bash

set -e
set -x
set -u

SIZE=$1
RESULTS_DIR=$2
SPARK_APP=${3:-/etc/demo/spark-pi.yaml}
HEURISTIC=${4:-punch}
NB_APP_RUN=${5:-5}
CORES_PER_NODE=${6:-16}

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

cleanup() {
  echo == Cleaning remaining jobs
  set +x
  oardel $(oarstat -J | jq '.[] | .id') || true
  until [[ $(oarstat -J) == '{}' ]]
  do
    echo Waiting for remaining jobs to be killed...
    sleep 1
  done
  k3s kubectl delete all --all
  # Waiting for all resource to be properly delete to avoid deletion of Spark config
  sleep 5
  set -x
}

get_result() {
  set +e
  END_DATE=$(date '+%Y-%m-%d %H:%M:%S')

  echo "=== Kill HPC workflow submission"
  kill $PID
  echo "\n=== Copy results from $ESPSCRATCH to $RESULTS_DIR"
  mkdir -p $RESULTS_DIR/$EXPE_DIR
  cp -r $ESPSCRATCH/* $RESULTS_DIR/$EXPE_DIR
  echo === Get all history and logs
  oarstat --gantt "$START_DATE, $END_DATE" -Jf > $RESULTS_DIR/$EXPE_DIR/oar-jobs.json
  k3s kubectl get events -o json > $RESULTS_DIR/$EXPE_DIR/k8s-events.json
  # Copy this script
  cp "${BASH_SOURCE[0]}" $RESULTS_DIR/$EXPE_DIR/expe-script.sh
  journalctl -u bebida-shaker.service > $RESULTS_DIR/$EXPE_DIR/shaker.log
  # Add some metadata
  cat > $RESULTS_DIR/$EXPE_DIR/metadata.json <<EOF
{
  "start": "$START_DATE",
  "end": "$END_DATE",
  "heuristic": "$HEURISTIC",
  "nb_app_run": "$NB_APP_RUN"
}
EOF

  cleanup

  echo === Experiment done!
  echo Results are located here:
  echo $RESULTS_DIR/$EXPE_DIR
}

# Cleanup OAR before start
cleanup
# Prefetch the image on all nodes
k3s kubectl apply -f /etc/demo/pre-fetcher.yaml
k3s kubectl rollout status daemonset prepuller --timeout=300s
# Setup spark
k3s kubectl apply -f /etc/demo/spark-setup.yaml

# Get results on exit
trap get_result EXIT

# Now that everything is clean starts the experiment
export START_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# use -T 10 as runesp parameter to increase the load
su - user1 -c "export ESPHOME=$ESPHOME; export ESPSCRATCH=$ESPSCRATCH; runesp -v -T 10 -b OAR" &
PID=$!

# Put eventLogs in the user1 home result dir
SPARK_APP_TEMPLATED=$ESPSCRATCH/spark-app.yaml
sed s/%EXPE_DIR%/$EXPE_DIR/g  $SPARK_APP > $SPARK_APP_TEMPLATED

echo == Selected heuristic: $HEURISTIC
case $HEURISTIC in
  none)
    # Disable Bebida Shaker to be sure we are on a clean state
    systemctl stop bebida-shaker.service
    sleep 1
    systemctl status bebida-shaker.service | grep "Stopped BeBiDa Shaker service"
    ;;
  punch)
    # Reset Bebida Shaker to be sure we are on a clean state
    systemctl restart bebida-shaker.service
    ;;
  deadline)
    # Add annotations
    SPARK_APP_TMP=$SPARK_APP_TEMPLATED.tmp
    bebida-shaker annotate --deadline=$(date --iso-8601=seconds -d '2 mins') --cores=$CORES_PER_NODE --duration=1m $SPARK_APP_TEMPLATED > $SPARK_APP_TMP
    cp $SPARK_APP_TMP $SPARK_APP_TEMPLATED
    cat $SPARK_APP_TEMPLATED

    # Reset Bebida Shaker to be sure we are on a clean state
    systemctl restart bebida-shaker.service
    ;;
  annotated)
    # Add annotations
    SPARK_APP_TMP=$SPARK_APP_TEMPLATED.tmp
    bebida-shaker annotate --cores=$CORES_PER_NODE --duration=1m $SPARK_APP_TEMPLATED > $SPARK_APP_TMP
    cp $SPARK_APP_TMP $SPARK_APP_TEMPLATED
    cat $SPARK_APP_TEMPLATED

    # Reset Bebida Shaker to be sure we are on a clean state
    systemctl restart bebida-shaker.service
    ;;
  nohpc)
    kill $PID
    systemctl stop bebida-shaker.service
    ;;
  refill)
    # Reset Bebida Shaker to be sure we are on a clean state
    systemctl restart bebida-shaker.service

    source /etc/bebida/config.env
    bebida-shaker refill --cores=$CORES_PER_NODE
    ;;
esac

# Cleanup spark app
k3s kubectl delete -f $SPARK_APP_TEMPLATED || true

# Wait for the first HPC jobs to start
sleep 10

for run in $(seq $NB_APP_RUN)
do
    k3s kubectl apply -f $SPARK_APP_TEMPLATED
    k3s kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/spark-app-pi --timeout=3600s
    k3s kubectl get pod spark-app-pi -o json > $ESPSCRATCH/spark-app-pi-$run-pod.json
    k3s kubectl logs spark-app-pi > $ESPSCRATCH/spark-app-pi-$run-log.txt
    k3s kubectl delete -f $SPARK_APP_TEMPLATED
    sleep 5
done
echo Done!

