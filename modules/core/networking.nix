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

  # El bucle de muerte del pid file stale — por esto avahi "se rompía y rompía"
  # en los 4 hosts. El módulo de nixpkgs crea /run/avahi-daemon como avahi:avahi
  # (tmpfiles `d /run/avahi-daemon - avahi avahi -`) y endurece el daemon con
  # CapabilityBoundingSet SIN CAP_DAC_OVERRIDE: uid 0 dentro del sandbox NO puede
  # borrar nada en un dir de avahi (cae a la clase "other" de un 755 = sin
  # escritura). Cuando avahi muere de forma anómala (crash, kill -9, muerte rara
  # al boot), queda el pid file stale. En el siguiente arranque libdaemon
  # (daemon_pid_file_is_running) intenta borrarlo como root-sin-capacidad →
  # EACCES, y el return del unlink() se IGNORA → el create() posterior con
  # O_EXCL falla con EEXIST ("Failed to create PID file: File exists") → avahi no
  # vuelve a arrancar NUNCA más salvo limpieza manual. Con la red de Telmex caída
  # (eventos de interfaz a mansalva) la muerte anómala era continua → hosts
  # rotos en cadena.
  # Fix: que systemd gestione el dir (RuntimeDirectory). PID 1 lo crea avahi-owned
  # en cada start y borra TODO el dir en cada stop (aunque el proceso muera con
  # kill -9) → un pid stale NO PUEDE sobrevivir a un ciclo stop/start y avahi ni
  # siquiera necesita su unlink. El socket de activación del módulo se desactiva:
  # sin él, avahi crea su propio /run/avahi-daemon/socket (como avahi, en su dir)
  # y no quedan sockets fantasma de systemd apuntando a un inode borrado (que al
  # reiniciarse en cada switch chocaban con EADDRINUSE contra el socket vivo).
  systemd.services.avahi-daemon.serviceConfig.RuntimeDirectory = "avahi-daemon";
  systemd.services.avahi-daemon.serviceConfig.RuntimeDirectoryUser = "avahi";
  systemd.sockets.avahi-daemon.enable = lib.mkForce false;
  systemd.services.avahi-daemon.requires = lib.mkForce [];
}
