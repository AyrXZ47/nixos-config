{ pkgs, ... }:

{
  # Kernel CachyOS para TODOS los hosts (overlay de chaotic-nyx, ver flake.nix).
  # 7.3.0 compilado con clang thin-LTO y -O3, PREEMPT full, HZ 1000, hugepages
  # always, sched_ext y los parches de scheduler de CachyOS. zen era -O2 sin LTO.
  # Se DESCARGA de nyx-cache.chaotic.cx (kernel + modulos + kernel.dev cacheados
  # por ellos), asi que ningun host compila kernel.
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # POR QUE NO `-march=x86-64-v3` (medido 2026-10-26): la variante optimizada se
  # pide con `cachyOverride { cachyVars = ...kernel.cachyConfig.cachyVars // {
  # _processor_opt = "GENERIC_V3"; }; }` (ZEN4/-lto-znver4 emiten instrucciones
  # que un Zen3 no tiene). nyx no la cachea y, para colmo, este canal de nixpkgs
  # no tiene `rustc-1.99.0` en cache.nixos.org: el kernel lleva CONFIG_RUST=y, asi
  # que compilarlo arrastra la torre de Rust completa (rustc desde bootstrap,
  # cargo, rustc-wrapper, cargo-auditable, cargo-nextest, rustfmt) = 2-4 h la
  # primera vez y ~1-1.5 h por cada bump de nyx, a cambio de ~1-2% en el kernel
  # (memcpy/memset ya se despachan por runtime). `cachyOverride` no acepta apagar
  # CONFIG_RUST, asi que no hay atajo.
  # Cuando rustc vuelva a estar en cache.nixos.org (chequeo: pedir
  # `...kernel.outPath` de la variante v3 y mirar si su narinfo da 200), el costo
  # baja al kernel pelado (~30 min en la pc) y se sube a la Cachix del repo.
}
