# AMD Vivado Design Suite 2026.1 — síntesis/implementación y programación de
# FPGAs (Arquitectura de computadoras: Basys3/Nexys4, ambas Artix-7).
#
# Vivado NO vive en el store: se instala a mano con xsetup en
# ~/opt/Xilinx/Vivado/2026.1 (el instalador web exige cuenta AMD y la EULA no
# permite redistribuirlo; "no instalar nunca con sudo"). Este módulo aporta el
# wrapper FHS para que corra en NixOS: los binarios de Vivado son de distro
# genérica y piden /usr/lib, /bin/bash y libs del sistema — el buildFHSEnv
# monta un /usr/lib completo con las libs de nixpkgs.
#
# Guía base (2019.2): https://oliverkovacs.dev/blog/2025/05/02/installing-vivado-on-nixos.html
# Diferencias en 2026.1: el instalador web exige `xsetup -b AuthTokenGen`
# (login AMD) antes del Install; los EULA tokens son solo XilinxEULA,3rdPartyEULA.
# Los .desktop que crea el instalador apuntan al binario real: editar su línea
# `Exec=` a solo `vivado` (el wrapper del PATH) si se quiere lanzar desde el menú.
#
# Cable driver (JTAG): Vivado trae `install_drivers`, pero escribe en
# /etc/udev/rules.d (read-only en NixOS) y su unbind usa /bin/sh (inexistente).
# Se traduce a `services.udev.extraRules` más abajo.
#
# ponytail: targetPkgs calibrados para 2026.1; si un rebuild pide una lib
# extra (p.ej. libtinfo.so.5 en 2019.2), añadirla aquí (1 línea).
{ config, pkgs, lib, ... }:

let
  # El rule original de Xilinx (52-xilinx-ftdi-usb.rules) suelta el FT2232H del
  # driver ftdi_sio, que si no lo retiene y Vivado no puede reclamar las
  # interfaces por libusb. Recibe %k (p.ej. "1-2") y suelta sus dos canales.
  unbindFtdi = pkgs.writeShellScript "xilinx-ftdi-unbind" ''
    for intf in "$1:1.0" "$1:1.1"; do
      if [ -e "/sys/bus/usb/drivers/ftdi_sio/$intf" ]; then
        echo -n "$intf" > "/sys/bus/usb/drivers/ftdi_sio/unbind"
      fi
    done
  '';

  vivadoDeps = with pkgs; [
    ncurses5  # libncurses.so.5 / libtinfo.so.5 (abi5 compat)
    ncurses   # libtinfo.so.6: la pide libxv_tcltasks
    pixman    # libpixman-1.so.0 (la piden los libxv_*)
    libpng    # libpng16.so.16
    zlib
    libuuid
    bash
    coreutils
    stdenv.cc.cc
    libxext
    libx11
    libxrender
    libxtst
    libxi
    libxft
    libxcb
    freetype
    fontconfig
    glib
    gtk2
    gtk3
    graphviz
    gcc
    unzip
    nettools
    libGL
  ];

  vivadoEnv = pkgs.buildFHSEnv {
    name = "vivado";
    targetPkgs = pkgs: vivadoDeps;
    # 2026.1 unifico el layout: el binario vive en <install>/2026.1/Vivado/bin,
    # no en <install>/Vivado/2026.1/bin como en 2019.2 (la guia del blog es vieja).
    # Los dlopen de Vivado no buscan en /usr/lib64 (donde nixpkgs deja las libs
    # del abi5 compat), se les pasa explicito por LD_LIBRARY_PATH.
    runScript = "env LD_LIBRARY_PATH=/usr/lib64:/usr/lib\${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} $HOME/opt/Xilinx/2026.1/Vivado/bin/vivado";
  };
in
{
  options.modules.apps.vivado.enable =
    lib.mkEnableOption "AMD Vivado Design Suite (síntesis FPGA; ~/opt/Xilinx)";

  config = lib.mkIf config.modules.apps.vivado.enable {
    environment.systemPackages = [ vivadoEnv ];

    # Cable driver Xilinx/Digilent (equivalente al install_drivers del vendor):
    # acceso rw al FT2232H (Basys3/Nexys4) y libera ftdi_sio para el JTAG.
    # Sin esto la placa no aparece en Hardware Manager → Auto Connect porque
    # /dev/bus/usb/*/* queda root:root 0644 y ftdi_sio retiene las interfaces.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", MODE="0666"
      ATTRS{idVendor}=="1443", MODE="0666"
      ACTION=="add", SUBSYSTEM=="usb", DEVTYPE=="usb_device", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", RUN+="${unbindFtdi} %k"
    '';
  };
}