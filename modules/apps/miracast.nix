{ pkgs, ... }:

{
  # Miracast (Wi-Fi Display, lo mismo que "Windows+K" en Windows): la app
  # GNOME pide el screencast al portal y lo transmite a la TV por P2P Wi-Fi.
  # Requiere red con NetworkManager + adaptador Wi-Fi con soporte P2P;
  # la TV Samsung debe tener activado "Screen Mirroring" / "Smart View".
  # Ceiling: Miracast en Linux es inconsistente (driver de Wi-Fi dependiente,
  # a veces descubre la TV, a veces no); si falla, el cable + SUPER+SHIFT+D
  # (espejo) sigue siendo el plan B fiable.
  home.packages = with pkgs; [
    gnome-network-displays
  ];
}
