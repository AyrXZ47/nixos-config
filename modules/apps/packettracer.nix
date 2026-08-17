# Cisco Packet Tracer 9.0.0 (Cisco Networking Academy, universidad) — simulador
# de redes. Módulo OPT-IN a propósito: usa `requireFile` (el .deb hay que
# meterlo al store a mano) y sin el archivo el build del host que lo active
# fallaría — default false en todos los hosts, así un repo clonado en una
# instalación limpia construye sin el archivo.
#
# El paquete ES el de nixpkgs (cisco-packet-tracer_9, 9.0.0): appimageTools
# maneja el AppImage estándar del 9.0.0 sin hacks. El 9.0.1 que NetAcad sirve
# hoy trae un "AppImage" roto (ELF stub + squashfs sin footer AI, ABI viejas
# libjpeg.so.8/libtiff.so.5 que nixpkgs ya no provee) — NO se usa; quedó
# documentado en el historial del repo. Ver README (sección Cisco Packet
# Tracer) para la activación y la URL pública del 9.0.0.
{ config, pkgs, lib, ... }:

{
  options.modules.apps.packetTracer.enable =
    lib.mkEnableOption "Cisco Packet Tracer (simulador de redes de Cisco)";

  config = lib.mkIf config.modules.apps.packetTracer.enable {
    environment.systemPackages = [ pkgs.cisco-packet-tracer_9 ];
  };
}