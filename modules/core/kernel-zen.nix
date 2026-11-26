{ pkgs, ... }:

{
  # Kernel zen de nixpkgs para TODOS los hosts (antes: CachyOS de chaotic-nyx,
  # removido 2026-11-26). Zen trae sched_ext (scx-loader funciona igual) y lo
  # construye Hydra con el toolchain del canal: como el canal solo se promueve
  # cuando Hydra termina, kernel + modulos siempre estan en cache.nixos.org.
  #
  # Por que se fue CachyOS: el arbol de modulos de linuxPackages_cachyos NO
  # esta en ninguna cache (ni nyx-cache ni cache.nixos.org, verificado con
  # nix path-info --store para 7.3.1 y 7.3.6) y su hash sigue el toolchain del
  # canal de nixpkgs. Resultado: cada bump del canal recompilaba el kernel
  # entero en cada host (1-1.5 h en la laptop), que era el cuello de botella
  # de todos los rebuilds. Lo que se pierde es el thin-LTO/-O3 de CachyOS
  # (~1-2% en el kernel, memcpy/memset ya se despachan por runtime, medido
  # 2026-10-26); el scheduler scx_lavd vive en userspace (sched_ext), no en
  # los parches de CachyOS.
  boot.kernelPackages = pkgs.linuxPackages_zen;
}
