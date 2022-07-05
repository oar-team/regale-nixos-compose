{ pkgs, nur, ... }: {
  nodes =
    let
      commonConfig = import ./common_config.nix { inherit pkgs nur; };
    in {
      
      eardb = { ... }: {
        imports = [ commonConfig ];
        environment.systemPackages = [  ];
        services.ear.database.enable = true;
      };
      
      eargm = { ... }: {
        imports = [ commonConfig ];
        services.ear.global_manager.enable = true;
      };
      
      node1 = { ... }: {
        imports = [ commonConfig ];
        services.ear.daemon.enable = true;
        services.ear.db_manager.enable = true;
      };
      
      node2 = { ... }: {
        imports = [ commonConfig ];
        services.ear.daemon.enable = true;
        services.ear.db_manager.enable = true;
      };
    };
  
  testScript = ''
      eardb.succeed("true")
  '';
}
