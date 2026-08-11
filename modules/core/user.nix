{ config, pkgs, lib, ... }:

{
  nixpkgs.config.allowUnfree = true;

  users.users.yovick = {
    isNormalUser = true;
    description = "Yovick R. Z.";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "i2c" "input" "wireshark" ];
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
    # Solo se aplica si el usuario aun no existe (primer boot); cambiala despues con `passwd`
    initialPassword = "yovick";
  };

  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];

  home-manager.backupFileExtension = "bak";

  security.sudo = {
    wheelNeedsPassword = true;
    extraRules = [];
  };
}
