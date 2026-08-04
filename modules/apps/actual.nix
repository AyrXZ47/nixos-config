{ config, pkgs, lib, ... }:

let
  # Actual Budget desktop app (Electron). No esta en nixpkgs (solo actual-server,
  # el servidor) asi que se empaqueta el AppImage oficial de los releases.
  actual-appimage = pkgs.fetchurl {
    url = "https://github.com/actualbudget/actual/releases/download/v26.8.0/Actual-linux-x86_64.AppImage";
    sha256 = "1p31qwr714q8x66fqwyxdc2ygvr1sh2sj5qj9ksqxq8fkzwrf4ny";
  };

  # Contenido del AppImage descomprimido (aporta .desktop e iconos hicolor).
  actual-extracted = pkgs.appimageTools.extract {
    pname = "actual-desktop";
    version = "26.8.0";
    src = actual-appimage;
  };

  # Binario ejecutable (wrapType2 crea un FHS env; no expone el .desktop).
  actual-bin = pkgs.appimageTools.wrapType2 {
    pname = "actual-desktop";
    version = "26.8.0";
    src = actual-appimage;
  };

  # .desktop e iconos con el Exec corregido (AppRun no existe fuera del AppImage).
  actual-data = pkgs.runCommand "actual-desktop-data" { } ''
    mkdir -p $out/share/applications $out/share/icons
    cp ${actual-extracted}/actual.desktop $out/share/applications/
    substituteInPlace $out/share/applications/actual.desktop \
      --replace-fail "Exec=AppRun" "Exec=actual-desktop"
    cp -r ${actual-extracted}/usr/share/icons/hicolor $out/share/icons/
  '';

  actual-desktop = pkgs.symlinkJoin {
    name = "actual-desktop";
    paths = [ actual-bin actual-data ];
  };
in
{
  options.modules.apps.actual.enable = lib.mkEnableOption "actual desktop app (Actual Budget)";

  config = lib.mkIf config.modules.apps.actual.enable {
    environment.systemPackages = [ actual-desktop ];
  };
}
