{ config, lib, pkgs, ... }:

let
  # Cache binaria propia (ver abajo). El workflow de CI usa el MISMO nombre:
  # si se cambia aca, cambia tambien en .github/workflows/binary-cache.yml.
  binaryCacheName = "ayrxz47-nixos-config";
  # Clave publica de la cache. Vacia = cache deshabilitada (no se agrega como
  # substituter ni como clave): el sistema queda igual que sin esto.
  binaryCacheKey = "+amyGHz3O38pkhJqZBhmM85KH/mYhCekYmjIolhRIkI=";

  # Mantenimiento con UNA sola regla de sudo (ver abajo). Un solo binario que
  # corre como root sin contraseña y que NO acepta comandos libres: solo los
  # subcomandos de su case. No es un sandbox (estos comandos escriben en el
  # store, el disco y el firmware), pero impide que un agente o un error
  # ejecute comandos arbitrarios como root.
  mantenimiento = pkgs.writeShellScriptBin "mantenimiento" ''
    set -uo pipefail
    export PATH=/run/current-system/sw/bin:$PATH
    nvme=/dev/nvme0
    [ -e "$nvme" ] || nvme=$(ls /dev/nvme[0-9] 2>/dev/null | head -1 || true)

    case "''${1:-}" in
      audit)
        echo "== sistema =="; readlink /run/current-system
        echo "== disco =="; df -h / | tail -1
        echo "== generaciones =="
        nix-env -p /nix/var/nix/profiles/system --list-generations | tail -8
        echo "== errores de este boot =="
        journalctl -p err -b --no-pager | tail -12
        ;;
      trim) fstrim -av ;;
      scrub) btrfs scrub start -B / && btrfs scrub status / ;;
      scrub-status) btrfs scrub status / ;;
      gc)
        nix-env -p /nix/var/nix/profiles/system --delete-generations +6
        nix-collect-garbage
        ;;
      optimise) nix-store --optimise ;;
      smart) smartctl -t short "$nvme" ;;
      smart-log) smartctl -a "$nvme"; smartctl -l selftest "$nvme" ;;
      fwupd)
        # Solo chequeo: lista lo que hay para flashear. El flash real es
        # `fwupd-apply`, y eso lo corre un humano (ver AGENTS.md).
        fwupdmgr refresh
        echo
        fwupdmgr get-updates || echo "sin actualizaciones de firmware pendientes"
        ;;
      # Flash real de firmware: a proposito SEPARADO de `all`. Un corte a mitad
      # de un flash no lo cubre el rollback de NixOS; lo corre un humano
      # decidiendo, con la maquina enchufada y quieta.
      fwupd-apply) fwupdmgr refresh --force; fwupdmgr update ;;
      clean|all)
        echo "== 1/5 trim =="; fstrim -av
        echo "== 2/5 scrub =="; btrfs scrub start -B /; btrfs scrub status /
        echo "== 3/5 generaciones + gc =="
        nix-env -p /nix/var/nix/profiles/system --delete-generations +6
        nix-collect-garbage
        echo "== 4/5 optimise =="; nix-store --optimise
        echo "== 5/5 smart (test corto, no bloquea) =="; smartctl -t short "$nvme"
        ;;
      # Equivalente al `-Syyu`: aplica el repo tal como está en disco. NO hace
      # `nix flake update` ni `git pull`: eso lo corre el humano o el agente
      # como yovick (git como root dejaria archivos con dueno root en el repo).
      upgrade)
        repo=/home/yovick/workspaces/nixos-config
        host="''${HOSTNAME#nixos-}"   # nixos-pc -> pc, nixos-laptop -> laptop
        echo "== upgrade: $repo#$host =="
        nixos-rebuild --impure switch --flake "$repo#$host"
        ;;
      # Ritual completo de Nix.md: actualizar y despues limpiar. Requiere que el
      # repo ya este actualizado (nix flake update + commit + push).
      full)
        "$0" upgrade
        "$0" clean
        ;;
      *)
        echo "uso: mantenimiento {audit|scrub-status|clean|all|full|upgrade|trim|scrub|gc|optimise|smart|smart-log|fwupd|fwupd-apply}" >&2
        exit 2
        ;;
    esac
  '';
in
{
  # ── Paralelismo absoluto ──────────────────────────────────────────────────
  # cores = 0   → Nix no se limita; usa todos los disponibles
  # max-jobs = auto → lanza tantos jobs como hilos lógicos
  nix.settings.cores = 0;
  nix.settings.max-jobs = "auto";

  # ── Scheduler idle → estabilidad en Hyprland ─────────────────────────────
  # Mientras compila, cede la CPU/IO al desktop para evitar freezes. Solo pesa
  # si hay competencia: sin carga, el build corre a full.
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  # ── Cachés binarios ──────────────────────────────────────────────────────
  # Evita compilar Hyprland desde cero
  nix.settings.substituters = (
    [
      "https://cache.nixos.org"
      "https://hyprland.cachix.org"
    ]
    # cache.nixos.org solo tiene lo que Hydra construyo desde el ARBOL de
    # nixpkgs. Los paquetes que nacen en los overlays de este flake no existen
    # ahi (404) y dos SI compilan: hypr-kdeconnect-fix (C++) y caelestia-shell
    # (QML parcheado). El workflow los construye en CI y los sube aca, asi que
    # ningun host los compila mas.
    #
    # Puesta en marcha (una vez): crear la cache en cachix.org con este mismo
    # nombre, `cachix use <nombre>` imprime la clave publica -> pegarla en
    # binaryCacheKey; y el token como secret del repo:
    #   gh secret set CACHIX_AUTH_TOKEN -b "$(cachix authtoken)"
    ++ lib.optional (binaryCacheKey != "") "https://${binaryCacheName}.cachix.org"
  );
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  ] ++ lib.optional (binaryCacheKey != "") "${binaryCacheName}.cachix.org-1:${binaryCacheKey}";

  # ── Flags experimentales (centralizado) ──────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ── Dedup automatico del store ───────────────────────────────────────────
  # Sin esto, cada rebuild deja copias completas de los mismos archivos (el
  # store llega a 130G+ con versiones viejas de libreoffice/uhd/clang y sources
  # duplicados de nixpkgs). Con auto-optimise-store cada path nuevo se hardlinkea
  # contra su contenido identico ya existente: el mismo archivo se guarda UNA vez.
  # OJO: es dedup al instalar, no un timer; no cuesta nada en el arranque.
  nix.settings.auto-optimise-store = true;

  # ── Timers de actualizacion: NINGUNO ──────────────────────────────────────
  # fwupd-refresh.timer corre CADA HORA con Persistent=true (nixpkgs lo mete en
  # timers.target): con la maquina apagada hace catch-up en el primer arranque,
  # el mismo patron que causaba los 9-10 min de arranque descritos abajo. El
  # chequeo de firmware se corre a mano cuando toca mantenimiento:
  #   sudo fwupdmgr refresh && sudo fwupdmgr update
  # (El timer solo baja metadatos, pero es automatico y cuadruplica el patron.)
  # enable=false no alcanza: el modulo de fwupd declara `wantedBy` sin condicion
  # y el symlink en timers.target igual se crea, asi que hay que vaciarlo.
  systemd.timers.fwupd-refresh = lib.mkIf config.services.fwupd.enable {
    enable = lib.mkForce false;
    wantedBy = lib.mkForce [ ];
  };

  # ── TRIM del SSD: A MANO ────────────────────────────────────────────────
  # services.fstrim viene enable=true por defecto: timer semanal con
  # Persistent=true, o sea catch-up en el primer arranque (misma familia de
  # problemas que los timers de arriba). El TRIM se corre en el mantenimiento:
  #   sudo fstrim -av
  # Sin TRIM periodico el SSD (NVMe sin DRAM en la laptop) pierde rendimiento de
  # escritura a la larga, asi que forma parte de la lista manual obligatoria.
  services.fstrim.enable = false;

  # ── Limpieza: A MANO (desde 2026-10-21) ──────────────────────────────────
  # Se eliminaron las cuatro automatizaciones (nix.gc, trim-generations,
  # nix.optimise y system.autoUpgrade). Todas eran Persistent=true y la maquina
  # esta apagada en sus horarios, asi que hacian catch-up SIMULTANEO en el
  # primer boot del dia: 9-10 min de GC + rebuild no-op sobre la NVMe sin DRAM,
  # compitiendo con el arranque de la sesion (laptop 2026-10-21: 10m29s de
  # userspace, con 5.5 min de nixos-upgrade clavado en "unpacking 1 channels").
  # autoUpgrade era no-op puro: `--upgrade` no hace nada en flakes y switcheaba
  # a la MISMA generacion cada vez. Con 3 generaciones tope no hay nada que
  # ganar corriendo esto solo; se corre cuando se hace mantenimiento:
  #   sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +3
  #   sudo nix-collect-garbage        # SIN -d: -d borra TODAS las generaciones
  #   sudo nix-store --optimise
  #   nix flake update && sudo nixos-rebuild switch --flake .#<host>

  # ── Generaciones: EXACTAMENTE 3, sin timer ────────────────────────────────
  # `boot.loader.systemd-boot.configurationLimit` (abajo) solo acota las
  # ENTRADAS del bootloader, no las generaciones del perfil: el perfil crece
  # igual, y esa es la razon de que el limite de 3 "nunca se respetara". Lo
  # unico que podaba era `nix.gc` (eliminado el 2026-10-21 por ser timer), asi
  # que desde entonces se acumulaban hasta que alguien corriera el
  # `--delete-generations +3` a mano.
  # Esto lo hace en cada activacion: son milisegundos, borra symlinks de
  # generacion (NO borra datos del store) y `nix-env` nunca elimina la
  # generacion en uso, ni siquiera despues de un rollback a una vieja.
  # Liberar el espacio sigue siendo manual a proposito: `nix-collect-garbage`
  # es lo que tarda, y el ritual ya lo corre.
  system.activationScripts.pruneSystemGenerations = ''
    ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system \
      --delete-generations +6 >/dev/null 2>&1 || true
  '';

  # ── Logs: journald acotado a 100M ─────────────────────────────────────────
  # Sustituye el journalctl --vacuum-size de Fedora: se limita una vez y nunca
  # más hay que vaciar a mano (equivalente al --vacuum-size=100M mensual).
  services.journald.settings.Journal.SystemMaxUse = "100M";

  # ── Consola: quiet en UN solo sitio, para todos los hosts ─────────────────
  # `splash` NO va aca: lo agrega el modulo de plymouth en los hosts que lo
  # tienen (pc/laptop/vm), y meterlo de nuevo solo duplicaba el parametro.
  # nixpkgs emite SIEMPRE `loglevel=${consoleLogLevel}` (default 4), asi que el
  # nivel se fija con la opcion, no metiendo otro loglevel= en kernelParams
  # (eso era justo el duplicado que quedo fuera). 3 y no 0: durante un freeze en
  # vivo la consola sigue mostrando crit/warn. No afecta al journal, que guarda
  # todo igual.
  boot.kernelParams = [ "quiet" ];
  boot.consoleLogLevel = 3;

  # ── Rebuild manual como root sobre un repo de yovick ─────────────────────
  # `sudo nixos-rebuild --flake /home/yovick/...` corre como root y libgit2
  # rechaza el repo por no ser suyo ("not owned by current user"). El
  # safe.directory del home de yovick no le aplica a root, por eso va en
  # /etc/gitconfig.
  environment.etc."gitconfig".text = ''
    [safe]
      directory = /home/yovick/workspaces/nixos-config
  '';

  # ── Boot: sin menú y 6 generaciones en el bootloader ────────────────────
  # timeout = 0 → systemd-boot arranca el default directo (sin espera ni menú);
  # configurationLimit = 6 → el bootloader conserva 6 entradas, en linea con la
  # poda del perfil (mas entradas no sirven de nada si el perfil no las tiene).
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.configurationLimit = 6;

  # ── Mantenimiento sin contraseña: UNA regla, acotada a un binario ────────
  # `mantenimiento <sub>` es lo unico que corre como root sin password. El
  # binario no acepta comandos libres (solo su `case`), asi que ni un error ni
  # una inyeccion pueden usarlo para otra cosa que no sea la lista de arriba.
  # Se cubren las dos formas del path porque sudo resuelve symlinks: la del
  # store (derivacion) y la de /run/current-system.
  environment.systemPackages = [ mantenimiento ];
  security.sudo.extraRules = [
    {
      users = [ "yovick" ];
      commands = [
        { command = "${mantenimiento}/bin/mantenimiento"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/mantenimiento"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];
}
