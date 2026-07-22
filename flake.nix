{
  description = "template for hydenix";

  inputs = {
    nixpkgs = {
      follows = "hydenix/nixpkgs";
    };
    hydenix.url = "github:richen604/hydenix";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";
  };

  outputs = { ... }@inputs:
    let
      mkConfig = host: inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/${host}/configuration.nix
        ];
      };

      vmConfigBase = mkConfig "vm";
      vmConfig = inputs.hydenix.lib.vmConfig {
        inherit inputs;
        nixosConfiguration = vmConfigBase;
      };
    in
    {
      nixosConfigurations.hydenix = vmConfigBase;
      nixosConfigurations.default = vmConfigBase;
      packages."x86_64-linux".vm = vmConfig.config.system.build.vm;
    };
}
