{ pkgs, ... }:

let
  # Mantenimiento de un host con UN comando, desde cualquier máquina.
  #
  #   deploy pc        -> rebuild local
  #   deploy laptop    -> ssh a nixos-laptop, git pull --ff-only y rebuild allá
  #
  # Usa `sudo -n mantenimiento upgrade`, no `nixos-rebuild` directo: es el único
  # binario con NOPASSWD (regla acotada en nix-optimization.nix) y ya pasa el
  # nyx-cache del kernel. Así el deploy es no interactivo y un agente puede
  # correrlo por SSH sin contraseña.
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
    mantenimiento=/run/current-system/sw/bin/mantenimiento

    # Local: el hostname es nixos-<host> y estamos en esa máquina.
    if [ "$me" = "nixos-$host" ]; then
      exec sudo -n "$mantenimiento" upgrade
    fi

    # Remoto: actualizar el repo ALLÁ y rebuildear. BatchMode falla rápido si
    # la clave no está autorizada en vez de pedir contraseña.
    exec ssh -o BatchMode=yes -o ConnectTimeout=8 "yovick@nixos-$host" \
      "git -C '$repo' pull --ff-only && sudo -n $mantenimiento upgrade"
  '';
in
{
  home.packages = [ deploy ];
}
