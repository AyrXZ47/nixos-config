{
  description = "NixOS configuration — modular, cyberpunk, flake-driven";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix.url = "github:danth/stylix";

    hyprpanel.url = "github:Jas-SinghFSU/Hyprpanel";
  };

  outputs =
    { nixpkgs, home-manager, stylix, hyprpanel, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      mkHost = hostName: hostModules: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          stylix.nixosModules.stylix

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.yovick = import ./home/default.nix;
            };
          }
        ] ++ hostModules;
      };
    in
    {
      nixosConfigurations = {
        vm = mkHost "vm" [ ./hosts/vm/configuration.nix ];
        pc = mkHost "pc" [ ./hosts/pc/configuration.nix ];
      };
    };
}
