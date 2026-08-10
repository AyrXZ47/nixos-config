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
      # ponytail: en Android (proot/FUSE) el unpack de srcs de directorio falla:
      # _defaultUnpack copia con `cp -r --preserve=timestamps --reflink=auto`
      # y el chmod final del destino muere con ENOENT (issue nix-community
      # #480, sin fix upstream). Los paquetes custom de nix-on-droid no van en
      # la cache -> se construyen en el celular y rompen (termux-am, termux-
      # tools). Con src = tarball (fetchurl) el unpack usa `tar xf`, que si
      # funciona. Ceiling: solo cubre estos dos paquetes; si otro paquete
      # custom se construye en el celular, convertirlo igual.
      androidUnpackFix = _final: prev: {
        fetchFromGitHub = args:
          if (args.repo or "") == "termux-am-socket" || (args.repo or "") == "termux-tools" then
            prev.fetchurl {
              name = "${args.repo}-${args.rev}.tar.gz";
              url = "https://github.com/${args.owner}/${args.repo}/archive/refs/tags/${args.rev}.tar.gz";
              sha256 = if args.repo == "termux-am-socket" then
                "sha256-UXUCPH/WdUkkUactBrdcdy8ldoW2n+EXInuuWl5vVJQ="
              else
                "sha256-HkCoxSxKIgUiSyy7dmJV4wSlFDKON6AilwdmaGMDLKo=";
            }
          else
            prev.fetchFromGitHub args;
      };

      pkgs = import nixpkgs {
        system = "aarch64-linux";
        overlays = [ androidUnpackFix ];
      };
    in
    {
      nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
        inherit pkgs;
        modules = [ ./configuration.nix ];
      };
    };
}
