{ config, pkgs, lib, ... }:

let
  # Actual Budget desktop app (Electron). No esta en nixpkgs (solo actual-server,
  # el servidor) asi que se empaqueta el AppImage oficial de los releases.
  actual-appimage = pkgs.fetchurl {
    url = "https://github.com/actualbudget/actual/releases/download/v26.8.0/Actual-linux-x86_64.AppImage";
    sha256 = "1p31qwr714q8x66fqwyxdc2ygvr1sh2sj5qj9ksqxq8fkzwrf4ny";
  };

  actual-desktop = pkgs.appimageTools.wrapType2 {
    pname = "actual-desktop";
    version = "26.8.0";
    src = actual-appimage;
  };
in
{
  options.modules.apps.actual.enable = lib.mkEnableOption "actual desktop app (Actual Budget)";

  config = lib.mkIf config.modules.apps.actual.enable {
    environment.systemPackages = [ actual-desktop ];
  };
}
