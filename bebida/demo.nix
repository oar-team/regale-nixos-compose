{ ... }:
{
  environment.etc."demo/pod-sleep-100.yml" = {
    text = ''
      apiVersion: v1
      kind: Pod
      metadata:
        name: busybox-1
      spec:
        containers:
        - name: busybox
          image: busybox:1.28
          args:
          - sleep
          - "100"
    '';
  };
  environment.etc."demo/run-hpc-workload.sh" = {
    source = ./scripts/run-hpc-workload.sh;
  };
  environment.etc."demo/run-all.sh" = {
    source = ./scripts/run-all.sh;
  };
  environment.etc."demo/spark-setup.yaml" = {
    source = ./scripts/spark-sa.yaml;
  };
  environment.etc."demo/spark-pi.yaml" = {
    source = ./scripts/spark-pi.yaml;
  };
}
