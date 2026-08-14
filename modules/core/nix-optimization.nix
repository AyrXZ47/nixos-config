{ config, pkgs, lib, ... }:

{
  # ── Paralelismo absoluto ──────────────────────────────────────────────────
  # cores = 0   → Nix no se limita; usa todos los disponibles
  # max-jobs = auto → lanza tantos jobs como hilos lógicos
  nix.settings.cores = 0;
  nix.settings.max-jobs = "auto";

  # ── Scheduler idle → estabilidad en Hyprland ─────────────────────────────
  # Mientras compila, cede la CPU/IO al desktop para evitar freezes
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";

  # ── Cachés binarios ──────────────────────────────────────────────────────
  # Evita compilar Hyprland desde cero
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://hyprland.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  ];

  # ── Flags experimentales (centralizado) ──────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ── Basura: máximo 3 generaciones SIEMPRE (por conteo, no por edad) ──────
  # "--delete-generations +3" conserva las 3 más nuevas de cada perfil.
  # Antes era por edad ("--delete-older-than 3d") y 20 rebuilds en 3 días
  # dejaban 20 generaciones (se llegó a 42 durante la puesta a punto).
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-generations +3";
  };
  nix.optimise.automatic = true;

  # La dedup del store (nix-optimise.timer 03:45 + Persistent=true) hace
  # catch-up en cada boot matutino (la maquina esta apagada a esa hora) y lee
  # 1-3GB del store justo cuando se abren las apps. Con io/CPU idle no congela
  # el arranque de aplicaciones; la dedup sigue corriendo en los huecos.
  systemd.services.nix-optimise.serviceConfig = {
    Nice = 19;
    IOSchedulingClass = "idle";
    CPUSchedulingPolicy = "idle";
  };

  # ── Logs: journald acotado a 100M ─────────────────────────────────────────
  # Sustituye el journalctl --vacuum-size de Fedora: se limita una vez y nunca
  # más hay que vaciar a mano (equivalente al --vacuum-size=100M mensual).
  services.journald.extraConfig = "SystemMaxUse=100M";

  # ── Actualización automática semanal ──────────────────────────────────────
  # Rebuild semanal del flake YA CONFIRMADO. No corre `nix flake update`: para
  # avanzar los inputs bloqueados hay que correrlo a mano y commitear. Si el
  # repo estuviera sucio (WIP sin commit), el rebuild falla esa semana y
  # reintenta a la próxima.
  system.autoUpgrade = {
    enable = true;
    flake = "/home/yovick/workspaces/nixos-config";
  };

  # nixos-upgrade corre como root; libgit2 rechaza el repo del flake por no
  # ser de root ("not owned by current user") y el autoUpgrade semanal fallaba
  # en cada boot (29s quemados + 381MB escritos, y con Persistent=true
  # reintentaba en el siguiente arranque). El safe.directory del home de yovick
  # no le aplica a root, por eso va en /etc/gitconfig.
  environment.etc."gitconfig".text = ''
    [safe]
      directory = /home/yovick/workspaces/nixos-config
  '';

  # ── Boot: sin menú de generaciones y solo 3 en el bootloader ─────────────
  # timeout = 0 → systemd-boot arranca el default directo (sin espera ni menú);
  # configurationLimit = 3 → el bootloader conserva solo 3 entradas de generación.
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.configurationLimit = 3;
}
