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
  #
  # nyx-cache: el kernel de CachyOS y sus modulos viven ahi ya compilados. El
  # primer switch despues de cambiar de kernel corre con el nix.conf de la
  # generacion VIEJA, que no conoce esa cache -> sin estas flags nixos-rebuild
  # compilaria el kernel entero (~30 min por host). Idempotentes: cuando el
  # nix.conf nuevo ya las tiene, no cambian nada. Misma clave que declara el
  # modulo nyx-cache en flake.nix.
  nyxCache = "--option extra-substituters https://nyx-cache.chaotic.cx/ --option extra-trusted-public-keys nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=";
  deploy = pkgs.writeShellScriptBin "deploy" ''
    set -euo pipefail

    if [ $# -ne 1 ]; then
      echo "uso: deploy <pc|laptop|server|vm>" >&2
      exit 2
    fi

    host="$1"
    repo="$HOME/workspaces/nixos-config"
    me="$(hostname)"
    nyxCache="${nyxCache}"

    # Local: el hostname es nixos-<host> y estamos en esa máquina.
    if [ "$me" = "nixos-$host" ]; then
      exec sudo nixos-rebuild --impure switch --flake "$repo#$host" $nyxCache
    fi

    # Remoto: actualizar el repo ALLÁ y rebuildear con TTY para sudo.
    # --ff-only: si el repo remoto divergió, falla en vez de inventar un merge.
    exec ssh -t "yovick@nixos-$host" \
      "git -C '$repo' pull --ff-only && sudo nixos-rebuild --impure switch --flake '$repo#$host' $nyxCache"
  '';
in
{
  home.packages = [ deploy ];
}
