{ config, pkgs, lib, ... }:

{
  nixpkgs.config.allowUnfree = true;

  users.users.yovick = {
    isNormalUser = true;
    description = "Yovick R. Z.";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
  };

  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];

  home-manager.backupFileExtension = "bak";

  security.sudo.extraRules = [
    {
      users = [ "yovick" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
