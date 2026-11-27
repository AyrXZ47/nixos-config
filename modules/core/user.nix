{ config, pkgs, lib, ... }:

{
  nixpkgs.config.allowUnfree = true;
  # El update completo (nixpkgs 2026-11-03) marca EOL a estos paquetes que el
  # repo sigue usando a proposito: pybars3 por kikit (KiCad) y gtk2 por el
  # FHS de Vivado 2026.1. Se permiten hasta migrar; sin esto el sistema ni
  # siquiera evalua.
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
  # gtk2 solo llega por el rootfs FHS de Vivado 2026.1 (GTKWave 3.3.128 ya es
  # GTK3). No se puede sacar sin probar la GUI propietaria; nixpkgs lo elimina
  # en 27.05. Se silencia el warning y queda el deadline anotado en dotpm.
  nixpkgs.config.problems.handlers = { "gtk+".broken = "ignore"; };

  users.users.yovick = {
    isNormalUser = true;
    description = "Yovick RZ";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "i2c" "input" ];
    shell = pkgs.zsh;
    ignoreShellProgramCheck = true;
    # Clave de la laptop declarada en el repo: el pc tenia solo una clave
    # vieja y `deploy pc` fallaba con Permission denied. Asi cualquier host
    # reconstruido acepta a la laptop sin editar ~/.ssh/authorized_keys a mano.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQCn6Vxhsc7fmojHce1DvqYiweZ9fs/kwWcq0c0yLlL yovick@nixos-laptop"
      # Ya estaba en ~/.ssh/authorized_keys de la laptop sin comentario; se
      # etiqueta como la del pc para que ambos lados queden declarados.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIFfYnctaaFb4U6oKOBF/XwXA2pOclCV1H7PVq43j046 yovick@nixos-pc"
    ];
    # El password inicial lo pone ./bootstrap.sh con `chpasswd` después del
    # primer switch. Así la evaluación del flake queda pura: no se lee ningún
    # archivo fuera del store y `nixos-rebuild` ya no necesita `--impure`.
  };

  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];

  home-manager.backupFileExtension = "bak";

  security.sudo.wheelNeedsPassword = true;
}
