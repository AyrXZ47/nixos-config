{
  description = "nix-on-droid (Termux/celular) — config sincronizada con el repo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-on-droid }:
    let
      pkgs = import nixpkgs { system = "aarch64-linux"; };
    in
    {
      nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
        inherit pkgs;
        modules = [ ./configuration.nix ];
      };
    };
}
