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
  # Obsidian se queda en electron_42 a proposito (electron 43 rompe el
  # renderer, ver home/default.nix). nixpkgs lo marca EOL/inseguro; se
  # permite mientras el override siga siendo necesario.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-42.11.18"
    "python3.14-pybars3-0.9.7"
  ];
  # gtk2 esta marcado broken/EOL en nixpkgs; alguna app (gtkwave) aun lo usa.
  # Se permite con warning mientras se migra o se quita la app.
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
