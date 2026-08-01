{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/theming/theme-base.nix
    ../../modules/theming/plymouth.nix
    ../../modules/hardware/amd-desktop.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/flatpak.nix
    ../../modules/apps/gaming.nix
  ];

  modules.desktop.hyprland = {
    enable = true;
    screenshotKey = "SUPER SHIFT, P";
    screenshotWindowKey = "SUPER ALT, P";
    screenshotScreenKey = "SUPER, P";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  networking.hostName = "nixos-pc";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # OpenRGB: instala 60-openrgb.rules (vienen en el paquete); sin ellas avisa
  # "udev rules are not installed" y no puede tocar los dispositivos RGB.
  services.udev.packages = [ pkgs.openrgb ];

  # OpenRGB en Gigabyte: el SMBus de las RAM (AMD FCH, /dev/i2c via i2c-piix4)
  # no se vincula porque ACPI reclama el rango 0xB00 (OpRegion \GSA1.SMBI).
  # `lax` deja que el driver i2c-piix4 acceda al bus y OpenRGB vea las RAM.
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];

  # ddcci: expone el monitor externo (DDC/CI) como /sys/class/backlight/ddcci0.
  # Asi wayle (modulo brightness nativo: dropdown + OSD) y brightnessctl pueden
  # controlar el brillo, sin depender de ddcutil por cada cambio. Sin esto no hay
  # /sys/class/backlight en este PC (monitor externo) y el brillo solo va por DDC.
  boot.extraModulePackages = [ config.boot.kernelPackages.ddcci-driver ];
  boot.kernelModules = [ "ddcci" "ddcci-backlight" ];

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

}
