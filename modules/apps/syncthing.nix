{ config, pkgs, lib, ... }:

{
  # syncthing por defecto en todos los hosts: arranca el daemon + Web UI en
  # 127.0.0.1:8384. Corre como yovick (el user por defecto "syncthing" no tiene
  # permisos sobre /home/yovick) con config en /home/yovick/.config/syncthing.
  services.syncthing = {
    enable = true;
    user = "yovick";
    dataDir = "/home/yovick";
  };
}