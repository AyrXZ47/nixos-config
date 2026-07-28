{ config, pkgs, lib, ... }:

{
  users.users.yovick = {
    isNormalUser = true;
    description = "Yovick R. Z.";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.zsh;
  };

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
