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

  # avahi crea /run/avahi-daemon y lo chown al usuario 'avahi' (make_runtime_dir).
  # El bounding set del módulo de NixOS (CAP_SYS_CHROOT/SETUID/SETGID) NO incluye
  # CAP_CHOWN, así que el chown falla en silencio (avahi ignora el return), el dir
  # queda root:root y avahi aborta con "Failed to create runtime directory".
  # Solo funcionaba mientras el dir pre-existía con dueño avahi (de un arranque
  # anterior), por eso rompía al reiniciar el servicio en un switch.
  # Se añade CAP_CHOWN al bounding set: avahi vuelve a crear/chownear el dir en
  # cada arranque y el pid file stale se gestiona solo (dir avahi-owned).
  systemd.services.avahi-daemon.serviceConfig.CapabilityBoundingSet = [ "CAP_CHOWN" ];
}
