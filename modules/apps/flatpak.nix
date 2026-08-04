{ config, pkgs, lib, ... }:

{
  services.flatpak.enable = true;

  environment.systemPackages = [ pkgs.flatpak ];

  # Actualización automática semanal de flatpaks (en la sesión de usuario,
  # porque los flatpaks de este setup son --user). Corre solo cuando estás
  # logueado; Persistent recupera el update perdido en el siguiente arranque.
  systemd.user.services.flatpak-update = {
    description = "Actualiza flatpaks";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.flatpak}/bin/flatpak update -y --noninteractive";
    };
  };

  systemd.user.timers.flatpak-update = {
    description = "Actualización semanal de flatpaks";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  systemd.user.services.flatpak-flathub = {
    description = "Add Flathub remote";
    wantedBy = [ "default.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.flatpak}/bin/flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
}
