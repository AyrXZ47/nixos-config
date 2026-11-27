{ config, pkgs, lib, ... }:

let
  # Del paquete de adi1090x solo usamos Ironman. Copiar el tema a un paquete
  # propio evita arrastrar el catálogo completo de temas al initrd.
  ironmanPlymouth = pkgs.runCommand "plymouth-theme-ironman" { } ''
    mkdir -p $out/share/plymouth/themes
    cp -r ${pkgs.adi1090x-plymouth-themes}/share/plymouth/themes/ironman \
      $out/share/plymouth/themes/ironman
  '';
in
{
  boot.plymouth = {
    enable = true;
    theme = lib.mkForce "ironman";
    themePackages = lib.mkForce [ ironmanPlymouth ];
  };

  # initrd con systemd es obligatorio desde que nixpkgs saco el stage 1 scripted
  # (26.11): `boot.initrd.systemd.enable` y `boot.initrd.verbose` ya no existen
  # como opciones, su sola definicion es un error de evaluacion.
  # quiet/splash/loglevel viven UNA vez en modules/core/nix-optimization.nix
  # (todos los hosts). consoleLogLevel=0 se saco: fijaba loglevel=0 y dejaba la
  # consola muda justo cuando se necesita ver un freeze en vivo.
  boot.kernelParams = [
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
  ];
}
