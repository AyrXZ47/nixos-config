# Cisco Packet Tracer 9.0.0 (Cisco Networking Academy, universidad) — simulador
# de redes. Activo en los hosts gráficos (pc/laptop/vm) con el flag
# modules.apps.packetTracer.enable.
#
# POR QUÉ ESTÁ VENDORIZADO Y NO SALE DE pkgs.cisco-packet-tracer_9:
# nixpkgs avanza el paquete al ritmo de Cisco (el bump de 2026-09-16 lo pasó de
# 9.0.0 a 9.0.1) y el 9.0.1 de NetAcad viene en formato roto (ELF stub + squashfs
# sin footer AI + ABI viejas libjpeg.so.8/libtiff.so.5 que nixpkgs ya no provee).
# Además nixpkgs lo pinea con requireFile (bajarlo a mano), mientras que el 9.0.0
# se sirve público en Archive.org con hash conocido. Este módulo es la definición
# de nixpkgs 9.0.0 con la fuente cambiada a fetchurl: una instalación limpia
# (clone -> bootstrap.sh) baja el .deb SOLO, y N máquinas reconstruyen igual.
#
# ponytail: si Archive.org moviera el item, el rebuild falla con el fetch —
# actualizar la URL/hash aquí (1 línea). Mismo trade-off de cualquier fuente
# pineada.
{ config, pkgs, lib, ... }:

let
  pt = pkgs.appimageTools.wrapType2 rec {
    pname = "cisco-packet-tracer";
    version = "9.0.0";

    # appimageTools envuelve el AppImage estándar del 9.0.0 sin hacks. El .deb
    # (formato Debian) se desempaqueta con dpkg para sacar opt/pt/packettracer.AppImage.
    src = pkgs.stdenvNoCC.mkDerivation {
      pname = "cisco-packet-tracer-appimage";
      inherit version;

      src = pkgs.fetchurl {
        name = "CiscoPacketTracer_900_Ubuntu_64bit.deb";
        url = "https://archive.org/download/packettracer900/CiscoPacketTracer_900_Ubuntu_64bit.deb";
        hash = "sha256-3ZrA1Mf8N9y2j2J/18fm+m1CAMFEklJuVhi5vRcu2SA=";
      };

      nativeBuildInputs = [ pkgs.dpkg ];

      installPhase = ''
        runHook preInstall
        cp opt/pt/packettracer.AppImage $out
        runHook postInstall
      '';
    };

    extraPkgs = _: [
      pkgs.libpng
      pkgs.libxkbfile
    ];

    extraBwrapArgs = [
      # fixes launch on wayland when the user sets QT_QPA_PLATFORM=wayland:
      # "Fatal: This application failed to start because no Qt platform plugin could be initialized."
      "--setenv QT_QPA_PLATFORM xcb"
    ];

    extraInstallCommands =
      let
        contents = pkgs.appimageTools.extract { inherit pname version src; };
      in
      ''
        mv $out/bin/${pname} $out/bin/packettracer9

        install -Dm444 ${contents}/CiscoPacketTracer-9.0.0.desktop $out/share/applications/cisco-packet-tracer-9.desktop
        # El .desktop del PTSA (agente de sesión de Cisco) es inútil para el
        # humano y duplicaba el icono en el lanzador: no se instala.
        substituteInPlace $out/share/applications/* \
          --replace-fail "Exec=@EXEC_PATH@" "Exec=packettracer9" \
          --replace-fail "Icon=app" "Icon=cisco-packet-tracer-9"

        install -Dm444 ${contents}/usr/share/icons/hicolor/48x48/apps/app.png $out/share/icons/hicolor/48x48/apps/cisco-packet-tracer-9.png
        cp -r ${contents}/usr/share/icons/gnome/48x48/mimetypes $out/share/icons/hicolor/48x48/

        for desktop in $out/share/applications/*.desktop; do
          sed -i '/^\[Desktop Entry\]/a StartupWMClass=PacketTracer' "$desktop"
        done
      '';

    meta = {
      description = "Network simulation tool from Cisco";
      homepage = "https://www.netacad.com/courses/packet-tracer";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };
in
{
  options.modules.apps.packetTracer.enable =
    lib.mkEnableOption "Cisco Packet Tracer (simulador de redes de Cisco)";

  config = lib.mkIf config.modules.apps.packetTracer.enable {
    environment.systemPackages = [ pt ];
  };
}
