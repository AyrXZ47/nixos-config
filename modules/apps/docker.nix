{ config, pkgs, lib, ... }:

{
  # Docker rootless: se conserva Docker (CLI, imágenes, compose) pero el daemon
  # corre como yovick y NO existe el grupo `docker` (que equivalía a root).
  # El daemon arranca con la sesión del usuario, no en boot del sistema.
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
    # `nft` no está en el PATH del daemon; sin esto avisa al iniciar que no
    # puede limpiar las reglas IPv6 de nftables.
    extraPackages = [ pkgs.nftables ];
  };

  # El módulo crea el servicio para todo usuario no-root, incluido el greeter
  # `sddm` (uid 175), que no tiene subuid y falla. Solo yovick lo corre.
  systemd.user.services.docker.unitConfig.ConditionUser = lib.mkForce "yovick";
}
