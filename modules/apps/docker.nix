{ config, pkgs, lib, ... }:

{
  # Docker rootless: se conserva Docker (CLI, imágenes, compose) pero el daemon
  # corre como yovick y NO existe el grupo `docker` (que equivalía a root).
  # El daemon arranca con la sesión del usuario, no en boot del sistema.
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
}
