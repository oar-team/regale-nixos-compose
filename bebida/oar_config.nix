{ pkgs
, modulesPath
, nur
, flavour
,
}:
let
  inherit
    (import "${toString modulesPath}/tests/ssh-keys.nix" pkgs)
    snakeOilPrivateKey
    snakeOilPublicKey
    ;
  scripts = import scripts/scripts.nix { inherit pkgs; };
in
{
  imports = [ nur.repos.kapack.modules.oar ];

  environment.variables.OMPI_ALLOW_RUN_AS_ROOT = "1";
  environment.variables.OMPI_ALLOW_RUN_AS_ROOT_CONFIRM = "1";

  environment.systemPackages = [
    pkgs.cpufrequtils

    pkgs.nur.repos.kapack.npb
    pkgs.openmpi
  ];

  networking.firewall.enable = false;

  services.openssh.extraConfig = ''
    AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
    AuthorizedKeysCommandUser nobody
  '';

  environment.etc."oar/bebida_prolog.sh".source = ./scripts/master-prolog-oar.sh;
  environment.etc."oar/bebida_epilog.sh".source = ./scripts/master-epilog-oar.sh;

  environment.etc."privkey.snakeoil" = {
    mode = "0600";
    source = snakeOilPrivateKey;
  };
  environment.etc."pubkey.snakeoil" = {
    mode = "0600";
    #source = snakeOilPublicKey;
    text = snakeOilPublicKey;
  };

  environment.etc."oar-dbpassword".text = ''
    # DataBase user name
    DB_BASE_LOGIN="oar"

    # DataBase user password
    DB_BASE_PASSWD="oar"

    # DataBase read only user name
    DB_BASE_LOGIN_RO="oar_ro"

    # DataBase read only user password
    DB_BASE_PASSWD_RO="oar_ro"
  '';

  # environment.etc."oar-quotas-buggy.json" = {
  #   text = ''
  #     {
  #       "periodical": [
  #           ["* * * *", "quotas_default", "osef lol"]
  #       ],
  #       "oneshot": [
  #       ],
  #       "quotas_default": {
  #         "*,*,*,*": [-1, -1, -1]
  #       },
  #       "time-critical": {
  #         "*,*,*,*": [-1, -1, -1]
  #       }
  #     }
  #   '';
  #   mode = "0777";
  # };

  environment.etc."oar/quotas.json" = {
    text = ''
      {
        "quotas": {
          "*,*,*,*": [-1, -1, -1]
        }
      }
    '';
    mode = "0777";
  };


  services.oar = {
    extraConfig = {
      LOG_LEVEL = "3";
      HIERARCHY_LABELS = "resource_id,network_address,cpuset";
      QUOTAS = "yes";
      QUOTAS_CONF_FILE = "/etc/oar/quotas.json";
      SERVER_PROLOGUE_EXEC_FILE = "/etc/oar/bebida_prolog.sh";
      SERVER_EPILOGUE_EXEC_FILE = "/etc/oar/bebida_epilog.sh";
    };

    # oar db passwords
    database = {
      host = "server";
      passwordFile = "/etc/oar-dbpassword";
      initPath = [ pkgs.util-linux pkgs.gawk pkgs.jq scripts.wait_db scripts.add_resources ];
      postInitCommands = ''
        num_cores=$(( $(lscpu | awk '/^Socket\(s\)/{ print $2 }') * $(lscpu | awk '/^Core\(s\) per socket/{ print $4 }') ))
        echo $num_cores > /etc/num_cores

        if [[ -f /etc/nxc/deployment-hosts ]]; then
          num_nodes=$(grep -E "node[0-9]+" /etc/nxc/deployment-hosts | wc -l)
        else
          num_nodes=$(jq -r '[.nodes[] | select(contains("node"))]| length' /etc/nxc/deployment.json)
        fi
        echo $num_nodes > /etc/num_nodes

        wait_db

        add_resources $num_nodes $num_cores
      '';
    };
    server.host = "server";
    privateKeyFile = "/etc/privkey.snakeoil";
    publicKeyFile = "/etc/pubkey.snakeoil";
  };
}
