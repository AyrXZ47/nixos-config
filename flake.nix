{
  description = "NixOS configuration — modular, cyberpunk, flake-driven";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      # Backend del portal RemoteDesktop para el remote input de KDE Connect en Hyprland.
      # kdeconnect (Wayland) inyecta teclado/raton via org.freedesktop.portal.RemoteDesktop
      # y ni wlr, gtk ni hyprland implementan esa interfaz; este shim la expone y reenvia
      # los eventos a zwlr_virtual_pointer/zwp_virtual_keyboard. No esta en nixpkgs.
      # Wiring: modules/desktop/hyprland-home.nix. Version 0.1.0, commit e86a0fb (2026-07-26).
      kdeconnectRemoteInputOverlay = final: prev: {
        hypr-kdeconnect-fix = prev.stdenv.mkDerivation {
          pname = "hypr-kdeconnect-fix";
          version = "0.1.0";
          src = prev.fetchFromGitHub {
            owner = "gfhdhytghd";
            repo = "hypr-kdeconnect-fix";
            rev = "e86a0fb17826cb8ea987665ded7428534e4a1a9d";
            hash = "sha256-VcXxVtlnkPjO6l0ky/n+0qa87Uc3c8hRM0twfgl+AiM=";
          };
          nativeBuildInputs = [ prev.cmake prev.pkg-config prev.wayland.dev prev.wayland-scanner ];
          buildInputs = [ prev.qt6.qtbase prev.libei prev.libxkbcommon prev.wayland ];
          # Daemon D-Bus sin QPA/QML: no necesita el wrapper de Qt.
          dontWrapQtApps = true;
          doCheck = true;
          meta = {
            description = "RemoteDesktop portal backend for KDE Connect remote input (Hyprland)";
            homepage = "https://github.com/gfhdhytghd/hypr-kdeconnect-fix";
            license = prev.lib.licenses.mit;
            maintainers = [ ];
            platforms = prev.lib.platforms.linux;
          };
        };
      };

      mkHost = hostName: hostModules: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Overlay visible en todos los modulos y en home-manager (useGlobalPkgs=true).
          { nixpkgs.overlays = [ kdeconnectRemoteInputOverlay ]; }
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
