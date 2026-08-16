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

      # Overlay de paquetes rotos en la punta de nixos-unstable: cuando el canal
      # pinna un hash que ya no coincide con el tarball real (GitHub re-genero el
      # tarball del tag, PyPI re-subio el sdist), un paquete bloquea TODO el
      # toplevel del sistema. En vez de esperar al fix upstream, se re-pinea el
      # hash localmente desde el fix de master (misma filosofia que un PKGBUILD
      # de AUR en Arch: paquete roto de upstream => parche local, sin esperar).
      # ponytail: techo conocido — cuando nixos-unstable publique el fix, el
      # override es redundante e inofensivo (mismo hash => misma derivacion);
      # borrarlo para no arrastrar mantenimiento muerto.
      unstableFixesOverlay = final: prev: let
        # Re-pinea SOLO el hash del source de nanoemoji al valor real del tarball
        # (el que el master de nixpkgs usa hoy). El resto de la derivación queda
        # igual; fetchFromGitHub es overridable.
        fixNanoemoji = p: p.overrideAttrs (old: {
          src = old.src.override {
            hash = "sha256-FysyKC01XBnRiur5RR9fcsTxQqE8x0JJHSoe3q6JtKc=";
          };
        });
      in {
        # jetbrains-mono (fuente de ${pkgs.jetbrains-mono}) construye con
        # python313Packages.gftools -> nanoemoji. Sin tocar python313Packages el
        # override no surte efecto (visto en la practica: hash mismatch persiste).
        nanoemoji = fixNanoemoji prev.nanoemoji;
        python313Packages = prev.python313Packages.overrideScope (pfinal: pprev: {
          nanoemoji = fixNanoemoji pprev.nanoemoji;
        });
        python3Packages = prev.python3Packages.overrideScope (pfinal: pprev: {
          nanoemoji = fixNanoemoji pprev.nanoemoji;
        });
      };

      mkHost = hostName: hostModules: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Overlay visible en todos los modulos y en home-manager (useGlobalPkgs=true).
          { nixpkgs.overlays = [ kdeconnectRemoteInputOverlay unstableFixesOverlay ]; }
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
