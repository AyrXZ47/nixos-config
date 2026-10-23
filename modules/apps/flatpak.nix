{ config, pkgs, lib, ... }:

{
  services.flatpak.enable = true;

  environment.systemPackages = [ pkgs.flatpak ];

  # Actualizaciones: MANUALES (2026-10-23). Antes habia un timer semanal
  # `flatpak-update` con Persistent=true: como la maquina pasa apagada, hacia
  # catch-up en el primer arranque del dia y competia con el arranque de la
  # sesion — el mismo patron que ya se elimino del lado de Nix (ver
  # modules/core/nix-optimization.nix). Nada de esto corre solo: se corre a mano
  # cuando toca mantenimiento.
  #   flatpak update -y
  #   flatpak uninstall --unused -y

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
