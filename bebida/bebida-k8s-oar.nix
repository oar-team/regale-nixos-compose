{ pkgs, modulesPath, nur, helpers, flavour, ... }: {
  roles =
    let
      commonConfig = import ./common_config.nix { inherit pkgs modulesPath; HPCScheduler = "OAR"; };
      oarConfig = import ./oar_config.nix { inherit pkgs nur flavour modulesPath; };
      tokenFile = pkgs.writeText "token" "p@s$w0rd";
    in
    {
      frontend = { ... }: {
        imports = [ commonConfig oarConfig ];
        nxc.sharedDirs."/users".server = "server";

        services.oar.client.enable = true;
        services.oar.web.enable = true;
        services.oar.web.drawgantt.enable = true;
        services.oar.web.monika.enable = true;
      };
      server = { ... }: {
        imports = [ commonConfig oarConfig ];
        nxc.sharedDirs."/users".export = true;

        services.oar.server.enable = true;
        services.oar.dbserver.enable = true;

        services.bebida-shaker.enable = true;

        # K3s utils
        environment.systemPackages = with pkgs; [ gzip jq kubectl ];

        system.activationScripts.k3s-config = ''
          SERVER=$( grep server /etc/nxc/deployment-hosts | ${pkgs.gawk}/bin/awk '{ print $1 }')
          echo 'bind-address: "'$SERVER'"' > /etc/k3s.yaml
          echo 'node-external-ip: "'$SERVER'"' >> /etc/k3s.yaml
        '';

        services.k3s = {
          inherit tokenFile;
          enable = true;
          role = "server";
          configPath = "/etc/k3s.yaml";
          environmentFile = pkgs.writeText "k3s-export" ''
            K3S_KUBECONFIG_OUTPUT=/etc/bebida/kubeconfig.yaml
            K3S_KUBECONFIG_MODE=666
          '';
        };
      };

      node = { ... }: {
        imports = [ commonConfig oarConfig ];
        nxc.sharedDirs."/users".server = "server";

        services.oar.node.enable = true;

        services.k3s = {
          inherit tokenFile;
          enable = true;
          role = "agent";
          serverAddr = "https://server:6443";
        };
      };
    };

  rolesDistribution = { node = 2; };

  testScript = ''
    # Submit job with script under user1
    frontend.succeed('su - user1 -c "cd && oarsub -l nodes=2 \"hostname\""')

    # Wait output job file
    frontend.wait_for_file('/users/user1/OAR.1.stdout')

    # Check job's final state
    frontend.succeed("oarstat -j 1 -s | grep Terminated")
  '';
}
