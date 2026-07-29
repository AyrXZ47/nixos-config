{ config, pkgs, lib, ... }:

{
  boot.plymouth = {
    enable = true;
    theme = lib.mkForce "ironman";
    themePackages = lib.mkForce [ pkgs.adi1090x-plymouth-themes ];
  };

  boot.initrd.systemd.enable = true;
  boot.initrd.verbose = false;
  boot.consoleLogLevel = 0;
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
}
