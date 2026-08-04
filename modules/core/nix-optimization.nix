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

  # ── Basura: mantener solo 3 generaciones atrás ───────────────────────────
  nix.gc = {
    automatic = true;
    dates = "daily";
    # "3d" obligatorio: "--delete-older-than 3" (sin unidad) rompe nix-gc
    # ("invalid number of days specifier '3', expected something like '14d'")
    options = "--delete-older-than 3d";
  };
  nix.optimise.automatic = true;

  # ── Límite duro de generaciones: máx 3 por CONTEo, no por edad ────────────
  # nix.gc es por EDAD: si haces 20 rebuilds en 3 días conserva 20 (pasó con
  # 42 generaciones durante la puesta a punto). Este servicio semanal borra
  # las generaciones más viejas hasta dejar exactamente las 3 más nuevas del
  # perfil de sistema y luego recoge la basura de la store.
  systemd.services.trim-generations = {
    description = "Deja solo las 3 generaciones mas recientes";
    serviceConfig = { Type = "oneshot"; };
    script = ''
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +3
      ${pkgs.nix}/bin/nix-collect-garbage -d
    '';
  };

  systemd.timers.trim-generations = {
    description = "Limpieza semanal de generaciones";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
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

  # ── Boot: sin menú de generaciones y solo 3 en el bootloader ─────────────
  # timeout = 0 → systemd-boot arranca el default directo (sin espera ni menú);
  # configurationLimit = 3 → el bootloader conserva solo 3 entradas de generación.
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.configurationLimit = 3;
}
