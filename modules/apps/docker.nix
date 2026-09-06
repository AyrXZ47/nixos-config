{ config, pkgs, lib, ... }:

{
  virtualisation.docker.enable = true;

  # Grupo docker = acceso al daemon (equivale a root en el host); yovick es el
  # unico usuario del setup. extraGroups concatena con los de core/user.nix.
  users.users.yovick.extraGroups = [ "docker" ];
}
