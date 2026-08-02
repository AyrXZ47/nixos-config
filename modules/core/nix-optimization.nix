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

  # ── Boot: sin menú de generaciones y solo 3 en el bootloader ─────────────
  # timeout = 0 → systemd-boot arranca el default directo (sin espera ni menú);
  # configurationLimit = 3 → el bootloader conserva solo 3 entradas de generación.
  boot.loader.timeout = 0;
  boot.loader.systemd-boot.configurationLimit = 3;
}
