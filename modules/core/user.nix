{ config, pkgs, lib, ... }:

let
  # Contrasena inicial SOLO para el primer boot (creacion del usuario). Ya NO esta
  # hardcodeada en el repo publico: se lee de un archivo local (solo root) que
  # ./bootstrap.sh crea en la primera instalacion. Si el archivo no existe, no se
  # define initialPassword (el usuario se crea sin password y en una maquina ya
  # instalada no cambia nada, pues /etc/shadow conserva la real).
  # Nota: la lectura es impura, asi que el rebuild va con `nixos-rebuild --impure`.
  passwordFile = "/etc/nixos-secrets/yovick-password";
  initialPassword =
    if builtins.pathExists passwordFile
    then lib.trim (builtins.readFile passwordFile)
    else null;
in {
  nixpkgs.config.allowUnfree = true;
  # El update completo (nixpkgs 2026-11-03) marca EOL a estos paquetes que el
  # repo sigue usando a proposito: pybars3 por kikit (KiCad) y gtk2 por
  # gtkwave. Se permiten hasta migrar; sin esto el sistema ni siquiera evalua.
  # electron_42 salio el 2026-11-05: Obsidian ya anda con electron 43 y no
  # queda ningun override que lo pida.
  nixpkgs.config.permittedInsecurePackages = [
    "python3.14-pybars3-0.9.7"
    # ventoy: nixpkgs lo marca insecure porque el release trae binarios
    # precompilados (busybox, shim, grub) que no se reconstruyen desde fuente ni
    # se pueden auditar (NixOS/nixpkgs#404663). Se permite a proposito: es la
    # unica herramienta que arma una USB multiboot copiando ISOs, sin reescribir
    # la memoria en cada instalacion. Va con version fija: si `nix flake update`
    # sube ventoy, hay que actualizar esta linea.
    "ventoy-1.1.18"
  ];
  nixpkgs.config.problems.handlers = { "gtk+".broken = "warn"; };

  users.users.yovick = {
    isNormalUser = true;
    description = "Yovick RZ";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "i2c" "input" "wireshark" ];
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
    # Solo se aplica si el usuario aun no existe (primer boot); cambiala despues con `passwd`
    initialPassword = lib.mkIf (initialPassword != null) initialPassword;
  };

  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];

  home-manager.backupFileExtension = "bak";

  security.sudo = {
    wheelNeedsPassword = true;
    extraRules = [];
  };
}
