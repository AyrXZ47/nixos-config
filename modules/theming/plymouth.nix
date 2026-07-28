{ config, pkgs, lib, ... }:

{
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
    themePackages = [ pkgs.adi1090x-plymouth ];
  };

  boot.initrd.systemd.enable = true;
  boot.consoleLogLevel = 0;
  boot.kernelParams = [
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
}
