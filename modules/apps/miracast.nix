{ pkgs, ... }:

{
  # Miracast (Wi-Fi Display, lo mismo que "Windows+K" en Windows): la app
  # GNOME pide el screencast al portal y lo transmite a la TV por P2P Wi-Fi.
  # Requiere red con NetworkManager + adaptador Wi-Fi con soporte P2P;
  # la TV Samsung debe tener activado "Screen Mirroring" / "Smart View".
  # Ceiling: Miracast en Linux es inconsistente (driver de Wi-Fi dependiente,
  # a veces descubre la TV, a veces no); si falla, el cable + SUPER+SHIFT+D
  # (espejo) sigue siendo el plan B fiable.
  #
  # dnsmasq: GND lo invoca por NOMBRE para servir DHCP en la interfaz
  # p2p-dev-wlpXsY una vez armado el grupo Wi-Fi. Sin el en PATH la TV nunca
  # recibe IP, la sesion de video no arranca y GND aborta con "connection
  # established .. connection lost". Va como paquete de usuario (no de sistema)
  # porque lo lanza la app de la sesion. Los puertos que tambien hacen falta
  # viven en modules/core/networking.nix: este archivo se importa desde
  # home/default.nix y no puede tocar el firewall del sistema.
  home.packages = with pkgs; [
    gnome-network-displays
    dnsmasq
  ];
}
