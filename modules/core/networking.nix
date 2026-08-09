{ config, pkgs, lib, ... }:

{
  # NetworkManager (wifi + ethernet + DHCP) y firewall, compartidos por todos
  # los hosts. El backend wifi NO se fuerza aquí: se usa el default de
  # NetworkManager (wpa_supplicant). Forzar `iwd` (antes en amd-laptop.nix)
  # dejaba un dispositivo fantasma (`/net/connman/iwd/0`, wifi-p2p disconnected)
  # que salía como "tachita" en la barra y abortaba la asociación del Wi-Fi
  # real (`iwd: Operation aborted`, "cannot connect"). El PC ya funcionaba bien
  # precisamente porque NO definía backend.
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # avahi (mDNS): KDE Connect lo usa para descubrir dispositivos en la misma
  # LAN, indistintamente de si van por ethernet, Wi-Fi 2.4G o 5G. Sin este, el
  # daemon corre pero no anuncia/ve a los móviles vía DNS-SD.

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  # avahi escribe su pid en /run/avahi-daemon/pid como el usuario 'avahi' tras
  # soltar privilegios. El módulo de NixOS no gestiona ese runtime dir: al
  # reiniciar el servicio en un switch queda un pid stale de root que avahi no
  # puede borrar ("Failed to create PID file: File exists") y nixos-rebuild
  # aborta la activación (exit 4). Con RuntimeDirectory, systemd crea/limpia el
  # dir con el dueño correcto en cada start/stop.
  systemd.services.avahi-daemon.serviceConfig = {
    RuntimeDirectory = "avahi-daemon";
    RuntimeDirectoryUser = "avahi";
    RuntimeDirectoryGroup = "avahi";
    RuntimeDirectoryMode = "0755";
  };
}