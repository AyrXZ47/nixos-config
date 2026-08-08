{
  description = "NixOS configuration — modular, cyberpunk, flake-driven";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wayland-wheeltani = {
      url = "github:docloulou/Wayland-Wheeltani";
      flake = false;
    };

  };

  outputs =
    { nixpkgs, home-manager, wayland-wheeltani, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      mkHost = hostName: hostModules: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit wayland-wheeltani; };
        modules = [
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.yovick = import ./home/default.nix;
            };
          }

          ./modules/core/nix-optimization.nix
        ] ++ hostModules;
      };
    in
    {
      nixosConfigurations = {
        pc = mkHost "pc" [ ./hosts/pc/configuration.nix ];
        laptop = mkHost "laptop" [ ./hosts/laptop/configuration.nix ];
        server = mkHost "server" [ ./hosts/server/configuration.nix ];
        vm = mkHost "vm" [ ./hosts/vm/configuration.nix ];
      };
    };
}
