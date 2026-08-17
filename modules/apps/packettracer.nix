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
# El hash es EL MISMO que pineó nixpkgs (sha256-3ZrA1... = flat del .deb).
# NO usar el 9.0.1 de NetAcad: su "AppImage" viene en formato roto (ELF stub +
# squashfs sin footer AI + ABI viejas libjpeg.so.8/libtiff.so.5 que nixpkgs ya
# no provee); documentado en el historial del repo.
#
# ponytail: si Archive.org moviera el item, el rebuild falla con el fetch —
# actualizar la URL aquí (1 línea). Es el mismo trade-off de cualquier fuente
# pineada (omnetpp usa GitHub releases).
{ config, pkgs, lib, ... }:

let
  pt = pkgs.cisco-packet-tracer_9.overrideAttrs (old: {
    src = old.src.overrideAttrs (o: {
      src = pkgs.fetchurl {
        url = "https://archive.org/download/packettracer900/CiscoPacketTracer_900_Ubuntu_64bit.deb";
        hash = "sha256-3ZrA1Mf8N9y2j2J/18fm+m1CAMFEklJuVhi5vRcu2SA=";
      };
    });
  });
in
{
  options.modules.apps.packetTracer.enable =
    lib.mkEnableOption "Cisco Packet Tracer (simulador de redes de Cisco)";

  config = lib.mkIf config.modules.apps.packetTracer.enable {
    environment.systemPackages = [ pt ];
  };
}