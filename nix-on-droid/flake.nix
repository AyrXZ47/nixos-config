{
  description = "nix-on-droid (Termux/celular) — config sincronizada con el repo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager nuevo: el que bundlea nix-on-droid (2024) no entiende la API
    # de los módulos home del repo (ej. programs.git.settings). Se fuerza uno
    # reciente para poder importarlos tal cual.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-on-droid }:
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
