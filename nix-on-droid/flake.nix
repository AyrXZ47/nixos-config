{
  description = "nix-on-droid (Termux/celular) — config sincronizada con el repo";

  inputs = {
    # Pinchado a nixos-25.11: glibc >=2.42 (unstable >=26.05) rompe el proot
    # 2024-05-04 bundleado del app (issue #495): tcgetattr falla con
    # 'Permission denied' al inicializar el build env de la activacion.
    # Con 25.11 (glibc 2.40) el proot actual funciona y el switch activa sin
    # pasos extra. Quitar el pin cuando el proot nuevo esté mergeado en
    # upstream de forma utilizable (PR #529; ver comentario del input
    # nix-on-droid).
    # ATENCION: cualquier cambio en este flake (incluido un comentario) cambia
    # el hash del source y con el TODAS las derivaciones que referencian
    # archivos locales (el tarball de opencode). Eso arregla "opencode: command
    # not found" tras un garbage collect: el output de opencode se construye
    # localmente (no viene de la cache binaria) y si el store lo pierde, el env
    # cacheado no re-materializa la dependencia y el symlink del profile queda
    # roto -> tocar este archivo y re-switch reconstruye todo.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # home-manager nuevo: el que bundlea nix-on-droid (2024) no entiende la API
    # de los módulos home del repo (ej. programs.git.settings). Se usa la rama
    # release-25.11, la pareja del nixpkgs pinchado (master exigiría
    # lib/services de nixpkgs post-25.11).
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
    };

    nix-on-droid = {
      # Anclado al master pre-PR #529 (55b6449b): el PR (update-proot) hardcodea
      # la ruta de store del proot nuevo que solo existe en la maquina del autor
      # (/nix/store/dvf2ck9...-unstable-2026-02-20; no esta ni en cache.nixos.org
      # ni en cachix) -> el switch muere con "path does not exist and cannot be
      # created" aunque el resto evalue bien. Con el master pre-PR se usan las
      # rutas del proot 2024-05-04 que el APK ya trae en el store del celular.
      #
      # El proot 2024-05-04 requiere glibc <2.42: por eso el pin de nixpkgs a
      # 25.11 (glibc 2.40) de arriba; juntos, switch sin pasos extra.
      #
      # Volver al PR/master nuevo cuando el proot 2026-02-20 este mergeado de
      # forma utilizable (con la ruta derivable, no hardcodeada) en upstream.
      url = "github:nix-community/nix-on-droid/55b6449b4582a4ba3ce712543c973360a026db7d";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Pi (el mismo input que el flake de los hosts de escritorio). OJO: aqui NO
    # se pone `inputs.nixpkgs.follows = "nixpkgs"`. Dos razones:
    #  1. El pin 25.11 de este flake NO trae `pkgs.pi` (verificado con nix eval:
    #     nixpkgs 25.11 no tiene el atributo); el paquete solo existe en el
    #     nixpkgs que el propio flake de pi trae.
    #  2. El flake de pi SI declara aarch64-linux (nix eval de
    #     packages.aarch64-linux.pi -> pi-1.2.0, verificado), que es lo que
    #     necesita el celular.
    # Consecuencia: este input agrega un segundo nixpkgs al lock de
    # nix-on-droid, aislado del pin 25.11 del resto (no afecta el proot).
    pi = {
      url = "github:earendil-works/pi";
      inputs.nixpkgs-darwin-x64.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nix-on-droid, pi }:
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

      # gentle-ai: binario Go del release oficial. El overlay de los hosts de
      # escritorio descarga el tarball linux_amd64 a fuego, y el pin 25.11 de
      # este flake no trae el paquete en nixpkgs -> aqui va su propio overlay
      # con el asset linux_arm64 (el release v4.1.1 SI lo publica; hash
      # obtenido con `nix store prefetch-file`).
      # Actualizar version: cambiar `version`, la `url` y el `hash`.
      gentleAiOverlay = final: prev: {
        gentle-ai = prev.stdenvNoCC.mkDerivation {
          pname = "gentle-ai";
          version = "4.1.1";
          src = prev.fetchurl {
            url = "https://github.com/Gentleman-Programming/gentle-ai/releases/download/v4.1.1/gentle-ai_4.1.1_linux_arm64.tar.gz";
            hash = "sha256-X4+jhXPuoPIRCQLwmWqgsAiqxY3A+aarvfMB3LyT9Os=";
          };
          sourceRoot = ".";
          installPhase = ''
            install -Dm755 gentle-ai $out/bin/gentle-ai
            install -Dm644 LICENSE $out/share/licenses/gentle-ai/LICENSE
          '';
          meta = {
            description = "Deterministic engineering environment for AI coding agents";
            homepage = "https://gentle-ai.gentlemanprogramming.com/";
            license = final.lib.licenses.mit;
            platforms = final.lib.platforms.linux;
            mainProgram = "gentle-ai";
          };
        };
      };

      pkgs = import nixpkgs {
        system = "aarch64-linux";
        overlays = [
          androidUnpackFix
          pi.overlays.default
          gentleAiOverlay
        ];
      };
    in
    {
      nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
        inherit pkgs;
        # El submódulo home-manager no hereda el `pkgs` con overlays del
        # modulo nix-on-droid, asi que se pasan por extraSpecialArgs (la
        # misma via que ya usan opencodeTarball/rtk) y configuration.nix los
        # re-expone al home con home-manager.extraSpecialArgs.
        #
        # opencode NO se declara como derivacion nix: su output standalone no
        # viene de la cache binaria y el store del celular lo pierde (path
        # corrupto/parcial, el env cacheado nunca lo re-materializa y el
        # symlink del profile queda muerto -> 'command not found' sin error).
        # En su lugar el tarball (verificado, sha256-KA7pKr...) viaja en el
        # flake source (re-copiado fresco en CADA switch) y home-manager lo
        # extrae a ~/.opencode/bin (ya en sessionPath) como activation:
        # autocurable, sin store path que se corrompa. Al subir de version:
        # reemplazar este archivo y ajustar la version en configuration.nix.
        # rtk sigue el mismo patrón por la misma razón: release prebuilt
        # aarch64 (ningún nixpkgs 25.11 tiene el paquete y unstable no corre
        # bajo este proot), tarball verificado commiteado (4 MB).
        extraSpecialArgs = {
          opencodeTarball = ./opencode-1.18.16.tar.gz;
          rtkTarball = ./rtk-0.48.0-aarch64.tar.gz;
          inherit nixpkgs pi gentleAiOverlay;
        };
        modules = [ ./configuration.nix ];
      };
    };
}
