{ pkgs, modulesPath, nur, helpers, ... }: {
  nodes =
    let
      commonConfig = import ./common_config.nix { inherit pkgs modulesPath nur; };
      fileSystemsNFSShared = {
        device = "server:/";
        fsType = "nfs";
      };

      node = { ... }: {
        imports = [ commonConfig ];
        fileSystems."/users" = fileSystemsNFSShared;
        services.oar.node.enable = true;
      };
    in {
      frontend = { ... }: {
        imports = [ commonConfig ];
        fileSystems."/users" = fileSystemsNFSShared;
        services.oar.client.enable = true;
      };

      server = { ... }: {
        imports = [ commonConfig ];
        services.oar.server.enable = true;
        services.oar.dbserver.enable = true;
        # NFS shared users' home
        services.nfs.server.enable = true;
        services.nfs.server.exports = ''
          /users *(rw,no_subtree_check,fsid=0,no_root_squash)
        '';
        nxc.postBootCommands = "mkdir -p /users && chmod 777 /users";

      };
    } // helpers.makeMany node "node" 2;

  testScript = ''
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
