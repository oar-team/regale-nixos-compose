{ pkgs, modulesPath, HPCScheduler }:
let
  inherit (import "${toString modulesPath}/tests/ssh-keys.nix" pkgs) snakeOilPrivateKey snakeOilPublicKey;
  toBase64 = (import ./helpers.nix { inherit (pkgs) lib; }).toBase64;
  sshPrivateKey = ./secrets/ssh_key;
  sshPublicKey = ./secrets/ssh_key.pub;
  bebidaEnvFile = pkgs.writeText "envFile" ''
    BEBIDA_SSH_PKEY=${toBase64 (builtins.readFile sshPrivateKey)}
    BEBIDA_SSH_HOSTNAME="frontend"
    BEBIDA_SSH_PORT="22"
    BEBIDA_SSH_USER="root"
    KUBECONFIG=/etc/bebida/kubeconfig.yaml
    BEBIDA_HPC_SCHEDULER_TYPE=${HPCScheduler}
    BEBIDA_CORES_PER_NODE=18
  '';
in
{
  # Inject key to permit localhost ssh from bebida-shaker
  users.users.root.openssh.authorizedKeys.keys = [
    (builtins.readFile sshPublicKey)
  ];

  services.bebida-shaker.environmentFile = bebidaEnvFile;
  environment.etc."bebida/config.env" = { source = bebidaEnvFile; };

  environment.systemPackages = [
    pkgs.python3
    pkgs.vim
    pkgs.cpufrequtils
    pkgs.python3Packages.clustershell
    pkgs.htop
    pkgs.tree
    pkgs.cri-tools
    pkgs.jq
  ];

  environment.noXlibs = false;

  environment.shellAliases = {
    k = "k3s kubectl";
    kubectl = "k3s kubectl";
    kgp = "k3s kubectl get pods -A";
  };

  # Allow root yo use open-mpi
  environment.variables.OMPI_ALLOW_RUN_AS_ROOT = "1";
  environment.variables.OMPI_ALLOW_RUN_AS_ROOT_CONFIRM = "1";

  nxc.users = { names = [ "user1" "user2" ]; prefixHome = "/users"; };

  security.pam.loginLimits = [
    { domain = "*"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "*"; item = "stack"; type = "-"; value = "unlimited"; }
  ];

  environment.etc."privkey.snakeoil" = {
    mode = "0600";
    source = snakeOilPrivateKey;
  };

  environment.etc."pubkey.snakeoil" = {
    mode = "0600";
    #source = snakeOilPublicKey;
    text = snakeOilPublicKey;
  };
}
