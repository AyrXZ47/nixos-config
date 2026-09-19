{ config, pkgs, lib, ... }:

let
  cfg = config.modules.desktop.caelestia;

  # Fuentes que las plantillas del shell piden (Sass/Qt QML resuelven por
  # fontconfig; Material Symbols es la de los iconos, Rubik la de la UI).
  fonts = with pkgs; [
    material-symbols
    rubik
    nerd-fonts.caskaydia-cove
  ];

  # Runtime que el shell invoca por nombre (la derivación de nixpkgs ya lo
  # envuelve, pero se instala explícito para que lo vea el PATH de la sesión y
  # no dependa de que el wrapper del paquete se use para lanzarlo).
  cliRuntime = with pkgs; [
    fuzzel
    slurp
    grim
    swappy
    gpu-screen-recorder
    dart-sass
    cliphist
  ];
in
{
  options.modules.desktop.caelestia = {
    enable = lib.mkEnableOption "Caelestia shell (Quickshell)";
  };

  config = lib.mkIf cfg.enable {
    # Caelestia no está en nixpkgs como módulo de NixOS ni en Home Manager
    # upstream: se instala el paquete (con el CLI embebido, `withCli = true` por
    # defecto) y la config estática va por xdg.configFile de Home Manager.
    environment.systemPackages = [
      pkgs.caelestia-shell
      pkgs.caelestia-cli
      pkgs.quickshell
    ] ++ fonts ++ cliRuntime;

    fonts.packages = fonts;

    # El lock de Caelestia (WlSessionLock) usa sus propias unidades PAM en
    # assets/pam.d/{passwd,fprint,howdy}, NO /etc/pam.d. Pero el CLI instala un
    # servicio PAM de sistema opcional; y allow_session_lock_restore /
    # session_lock_xray del Hyprland son del compositor, no del shell.
    #
    # Trap conocido del repo (README): security.pam.services.<name>.fprintAuth
    # defaulta a true con services.fprintd.enable, y eso rompía login/sddm. El
    # lock de Caelestia no usa /etc/pam.d, así que no se toca aquí; el fprint
    # del lock se valida en pruebas (fase 6).
  };
}
