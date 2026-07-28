{ config, pkgs, lib, ... }:

{
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
    themePackages = [ pkgs.adi1090x-plymouth ];
  };

  boot.kernelParams = [ "quiet" "splash" "rd.udev.log_level=3" ];
  console.logLevel = 0;
}
