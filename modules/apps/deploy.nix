{ pkgs, ... }:

let
  # Mantenimiento de un host con UN comando, desde cualquier máquina.
  #
  #   deploy pc        -> rebuild local (pide sudo normal)
  #   deploy laptop    -> ssh -t a nixos-laptop, git pull --ff-only y rebuild allá
  #
  # Por qué ssh -t y no `nixos-rebuild --target-host --use-remote-sudo`: -t le da
  # un TTY a sudo en el host remoto, que es lo unico que hace falta para que pida
  # la contraseña. Eso evita cualquier NOPASSWD (que en nixos-rebuild seria root
  # sin contraseña, porque el rebuild puede hacer cualquier cosa).
  #
  # Convención de nombres: host del flake `laptop` -> hostname/ssh `nixos-laptop`
  # (los cuatro hosts siguen el patrón; si uno no, el ssh falla con su error).
  deploy = pkgs.writeShellScriptBin "deploy" ''
    set -euo pipefail

    if [ $# -ne 1 ]; then
      echo "uso: deploy <pc|laptop|server|vm>" >&2
      exit 2
    fi

    host="$1"
    repo="$HOME/workspaces/nixos-config"
    me="$(hostname)"

    # Local: el hostname es nixos-<host> y estamos en esa máquina.
    if [ "$me" = "nixos-$host" ]; then
      exec sudo nixos-rebuild --impure switch --flake "$repo#$host"
    fi

    # Remoto: actualizar el repo ALLÁ y rebuildear con TTY para sudo.
    # --ff-only: si el repo remoto divergió, falla en vez de inventar un merge.
    exec ssh -t "yovick@nixos-$host" \
      "git -C '$repo' pull --ff-only && sudo nixos-rebuild --impure switch --flake '$repo#$host'"
  '';
in
{
  home.packages = [ deploy ];
}
