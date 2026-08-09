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

  # avahi deja un /run/avahi-daemon stale entre switches (pid file de una
  # generación anterior). Al reiniciar el servicio, avahi (tras soltar
  # privilegios a 'avahi') no puede borrar el pid viejo ("Failed to create PID
  # file: File exists") y nixos-rebuild aborta la activación (exit 4).
  # Nota: NO se usa systemd RuntimeDirectory para gestionar el dir: este
  # systemd no reconoce RuntimeDirectoryUser/Group ("Unknown key ... ignoring"),
  # así que el dir quedaría root:root y avahi falla con "Failed to create
  # runtime directory". ExecStartPre limpia el dir stale como root antes de
  # arrancar, y avahi vuelve a crearlo y chownearlo como siempre.
  systemd.services.avahi-daemon.serviceConfig.ExecStartPre = [ "${pkgs.coreutils}/bin/rm -rf /run/avahi-daemon" ];
}
