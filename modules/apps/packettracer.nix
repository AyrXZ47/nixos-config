# Cisco Packet Tracer 9.0.0 (Cisco Networking Academy, universidad) — simulador
# de redes. Activo por defecto en los hosts gráficos (pc/laptop/vm): el .deb
# del 9.0.0 se sirve PUBLICAMENTE en Archive.org (mirror del que NetAcad
# reparte), así que el rebuild lo descarga SOLO (fetchurl) — una instalación
# limpia (clone → bootstrap.sh) baja el .deb sin tocar nada, y 100 máquinas
# con el mismo repo reconstruyen igual, sin intervención manual ninguna.
#
# El paquete es el de nixpkgs (cisco-packet-tracer_9): appimageTools maneja el
# AppImage estándar del 9.0.0 sin hacks; aquí solo se reemplaza la fuente (el
# .deb) por la URL pública (requireFile upstream obliga a bajarlo a mano).
#
# nixpkgs (26.11) reestructuró el paquete: el requireFile ya no es el src
# directo del AppImage, vive en una derivación intermedia y el extraInstall-
# Commands del wrapType2 arrastra una extracción del original — el viejo truco
# de overrideAttrs sobre el src dejaba el requireFile en el grafo y el rebuild
# moría. Fix: override del requireFile que el paquete recibe por callPackage —
# para el .deb del 9.0.0 devuelve el fetchurl de Archive.org con EL MISMO hash
# que pinea nixpkgs; cualquier otro requireFile queda intacto.
# NO usar el 9.0.1 de NetAcad: su "AppImage" viene en formato roto (ELF stub +
# squashfs sin footer AI + ABI viejas libjpeg.so.8/libtiff.so.5 que nixpkgs ya
# no provee); documentado en el historial del repo.
#
# ponytail: si Archive.org moviera el item, el rebuild falla con el fetch —
# actualizar la URL aquí (1 línea). Es el mismo trade-off de cualquier fuente
# pineada (omnetpp usa GitHub releases).
{ config, pkgs, lib, ... }:

let
  pt = (pkgs.cisco-packet-tracer_9.override {
    requireFile = args:
      if args.name == "CiscoPacketTracer_900_Ubuntu_64bit.deb"
      then pkgs.fetchurl {
        inherit (args) name hash;
        url = "https://archive.org/download/packettracer900/${args.name}";
      }
      else pkgs.requireFile args;
  }).overrideAttrs (old: {
    # Entrada de escritorio del "PTSA" (agente de sesion de Cisco): inutil para
    # el humano, solo ensucia el lanzador con un icono duplicado. Se borra en
    # extraInstallCommands (no postInstall): upstream instala los .desktop ahi,
    # y postInstall corria ANTES dejando el PTSA de vuelta en cada rebuild.
    extraInstallCommands = (old.extraInstallCommands or "") + ''
      rm -f $out/share/applications/cisco-packet-tracer-ptsa-9.desktop
    '';
  });
in
{
  options.modules.apps.packetTracer.enable =
    lib.mkEnableOption "Cisco Packet Tracer (simulador de redes de Cisco)";

  config = lib.mkIf config.modules.apps.packetTracer.enable {
    environment.systemPackages = [ pt ];
  };
}