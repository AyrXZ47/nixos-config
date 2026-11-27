# Software común a los 4 hosts (pc, laptop, server, vm): shell/CLI, AI,
# Syncthing, utilidades y diagnóstico. Lo gráfico vive en desktop.nix; las
# suites pesadas, en engineering/media/dev.nix. Server lo importa solo: no
# arrastra GUI ni suites.
{ config, pkgs, lib, ... }:

let
  # pdf2md: PDF -> markdown con pymupdf (CPU). El modulo vive aparte porque el
  # check de `nix flake check` importa la misma derivacion que los hosts.
  pdf2md = import ./pdf2md.nix { inherit pkgs; };
in
{
  imports = [ ./syncthing.nix ];

  # Compat FHS: algunos agentes y reproductores de audio buscan rutas
  # absolutas de distro para notificaciones. NixOS no tiene /usr/bin; se crea
  # el symlink a pw-play (PipeWire) para que el sonido funcione sin depender de
  # que el binario este en el PATH del proceso que lanza la notificacion.
  system.activationScripts.fhsShims = {
    text = ''
      mkdir -p /usr/bin
      ln -sfn ${pkgs.pipewire}/bin/pw-play /usr/bin/pw-play
    '';
  };

  environment.systemPackages = with pkgs; [
    # ffmpeg-full: ÚNICO ffmpeg del sistema (libplacebo para tonemap HDR por
    # GPU vía Vulkan + libzimg). home/default.nix ya no instala `ffmpeg`.
    ffmpeg-full

    # PDF -> markdown para dar contexto (ver modules/apps/pdf2md.nix).
    pdf2md

    # Utilidades CLI
    android-tools
    cbonsai
    cmatrix
    ncdu
    openssl
    usbutils
    # Ventoy: USB multiboot (se copian las ISOs, no se reescribe la memoria).
    # Marcado insecure en nixpkgs por los blobs de upstream: ver user.nix.
    ventoy

    # Diagnóstico de hardware: slots de RAM y firmware del NVMe sin depender de
    # `nvme` a mano. `sudo mantenimiento smart-log` usa smartctl; esto suma
    # `dmidecode -t 17` y `nvme smart-log`. nvtop/amdgpu_top cubren la GPU.
    amdgpu_top
    dmidecode
    nvme-cli
    nvtopPackages.amd
    smartmontools

    # pnpm es un binario standalone: sin node en el PATH, los shims de
    # `pnpm dlx <pkg>` mueren con `exec: node: not found`. Lo necesita el CLI
    # de dotpm (MCP del tablero de Obsidian) y OpenCode en todos los hosts.
    nodejs
    pnpm
  ];
}
