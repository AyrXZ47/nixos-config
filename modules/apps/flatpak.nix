{ config, pkgs, lib, ... }:

{
  services.flatpak.enable = true;

  environment.systemPackages = [ pkgs.flatpak ];

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
