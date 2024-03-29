{
  pkgs,
  modulesPath,
  nur,
  helpers,
  flavour,
  ...
}: {
  roles = let
    dockerPorts.frontend = ["8443:443" "8000:80"];
    oarConfig = import ../lib/oar_config.nix {inherit pkgs modulesPath nur flavour;};
    commonConfig = import ../lib/common.nix {inherit pkgs modulesPath nur flavour;};
  in {
    node = {...}: {
      imports = [commonConfig oarConfig];
      services.oar.node = {enable = true;};
    };
    frontend = {...}: {
      imports = [commonConfig oarConfig];

      services.oar.client.enable = true;
      services.oar.web.enable = true;
      services.oar.web.drawgantt.enable = true;
    };
    server = {...}: {
      imports = [commonConfig oarConfig];

      services.oar.server.enable = true;
      services.oar.dbserver.enable = true;
    };
  };
  rolesDistribution = {node = 3;};

  testScript = ''
    frontend.succeed("true")
    # Prepare a simple script which execute cg.C.mpi
    frontend.succeed('echo "mpirun --hostfile \$OAR_NODEFILE -mca pls_rsh_agent oarsh -mca btl tcp,self cg.C.mpi" > /users/user1/test.sh')
    # Set rigth and owner of script
    frontend.succeed("chmod 755 /users/user1/test.sh && chown user1 /users/user1/test.sh")
    # Submit job with script under user1
    frontend.succeed('su - user1 -c "cd && oarsub -l nodes=2 ./test.sh"')
    # Wait output job file
    frontend.wait_for_file('/users/user1/OAR.1.stdout')
    # Check job's final state
    frontend.succeed("oarstat -j 1 -s | grep Terminated")
  '';
}
