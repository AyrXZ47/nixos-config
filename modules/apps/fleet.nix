{ config, pkgs, lib, ... }:

let
  repo = "${config.home.homeDirectory}/workspaces/nixos-config";
  # Los cuatro hosts del flake. Los que estén apagados se saltan solos.
  hosts = [ "nixos-pc" "nixos-laptop" "nixos-server" "nixos-vm" ];

  # Ritual de mantenimiento en TODOS los hosts online, desde el host donde
  # estés. Diseñado para que un agente lo corra sin TTY ni contraseña:
  #   mantenimiento-fleet status   -> estado de cada host
  #   mantenimiento-fleet audit    -> audit de cada host
  #   mantenimiento-fleet upgrade  -> git pull + rebuild en cada host
  #   mantenimiento-fleet all      -> trim/scrub/gc/optimise/smart en cada host
  #   mantenimiento-fleet fwupd    -> firmware pendiente (solo lista, no flashea)
  #   mantenimiento-fleet full     -> pull + check + upgrade + all + fwupd + tmp
  #
  # Requisitos: Tailscale arriba y la clave SSH de este host autorizada en los
  # demás (modules/core/user.nix declara las de laptop y pc; server/vm las
  # reciben al reconstruir). El rebuild usa `sudo -n mantenimiento upgrade`,
  # el único binario con NOPASSWD (ver nix-optimization.nix).
  fleet = pkgs.writeShellScriptBin "mantenimiento-fleet" ''
    set -uo pipefail

    export PATH=${lib.makeBinPath [ pkgs.openssh pkgs.git pkgs.coreutils pkgs.findutils ]}:$PATH

    repo="${repo}"
    hosts=(${lib.escapeShellArgs hosts})
    me="$(hostname)"
    mode="''${1:-status}"
    logdir="''${TMPDIR:-/tmp}/mantenimiento-fleet-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$logdir"

    case "$mode" in
      status|audit|upgrade|all|full|fwupd) ;;
      *) echo "uso: mantenimiento-fleet {status|audit|upgrade|all|full|fwupd}" >&2; exit 2 ;;
    esac

    remote_script() {
      case "$mode" in
        status)
          echo 'echo "host: $(hostname)"; echo "generation: $(readlink /run/current-system)"; df -h / | tail -1' ;;
        audit)
          echo 'sudo -n /run/current-system/sw/bin/mantenimiento audit' ;;
        upgrade)
          echo 'set -e; cd "$HOME/workspaces/nixos-config"; git pull --ff-only; sudo -n /run/current-system/sw/bin/mantenimiento upgrade' ;;
        all)
          echo 'sudo -n /run/current-system/sw/bin/mantenimiento all' ;;
        fwupd)
          echo 'sudo -n /run/current-system/sw/bin/mantenimiento fwupd' ;;
        full)
          echo 'set -e; cd "$HOME/workspaces/nixos-config"; git pull --ff-only; sudo -n /run/current-system/sw/bin/mantenimiento upgrade; sudo -n /run/current-system/sw/bin/mantenimiento all; sudo -n /run/current-system/sw/bin/mantenimiento fwupd || true; find /tmp -maxdepth 1 -user "$USER" -mtime +1 -exec rm -rf {} + 2>/dev/null || true' ;;
      esac
    }

    run_local() {
      case "$mode" in
        status)
          echo "host: $(hostname)"; echo "generation: $(readlink /run/current-system)"; df -h / | tail -1 ;;
        audit)
          sudo -n /run/current-system/sw/bin/mantenimiento audit ;;
        upgrade)
          set -e; cd "$repo"; git pull --ff-only; sudo -n /run/current-system/sw/bin/mantenimiento upgrade ;;
        all)
          sudo -n /run/current-system/sw/bin/mantenimiento all ;;
        fwupd)
          sudo -n /run/current-system/sw/bin/mantenimiento fwupd ;;
        full)
          set -e; cd "$repo"; git pull --ff-only
          sudo -n /run/current-system/sw/bin/mantenimiento upgrade
          sudo -n /run/current-system/sw/bin/mantenimiento all
          sudo -n /run/current-system/sw/bin/mantenimiento fwupd || true
          find /tmp -maxdepth 1 -user "$USER" -mtime +1 -exec rm -rf {} + 2>/dev/null || true ;;
      esac
    }

    # Antes de tocar hosts, validar la evaluacion de los 4 con el repo local.
    if [ "$mode" = "upgrade" ] || [ "$mode" = "full" ]; then
      ( cd "$repo" && git pull --ff-only && nix flake check ) || {
        echo "nix flake check fallo; no se toca ningun host" >&2
        exit 1
      }
    fi

    pids=(); names=(); logs=()
    for h in "''${hosts[@]}"; do
      log="$logdir/$h.log"
      if [ "$h" = "$me" ]; then
        run_local >"$log" 2>&1 &
      else
        ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
          "yovick@$h" "bash -s" <<<"$(remote_script)" >"$log" 2>&1 &
      fi
      pids+=($!); names+=("$h"); logs+=("$log")
    done

    rc=0
    for i in "''${!pids[@]}"; do
      if wait "''${pids[$i]}"; then
        echo "OK   ''${names[$i]}  (''${logs[$i]})"
      else
        st=$?
        if [ "$st" -eq 255 ]; then
          echo "SKIP ''${names[$i]}  (sin SSH; ''${logs[$i]})"
        else
          echo "FAIL ''${names[$i]}  (exit $st; ''${logs[$i]})"
          rc=1
        fi
      fi
    done

    echo "logs: $logdir"
    exit $rc
  '';
in
{
  home.packages = [ fleet ];
}
