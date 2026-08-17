# Cisco Packet Tracer (universidad, Cisco Networking Academy) — simulador de
# redes de Cisco. Módulo OPT-IN a propósito: el paquete usa `requireFile`
# (Cisco no permite descarga automática del .deb, solo detrás del login de
# NetAcad), así que sin el archivo en el store el build de ESE host falla. Si
# viviera en common-packages, secuestraría el rebuild de todos los hosts;
# con el flag, un host sin el módulo construye sin el archivo. Activación:
#   modules.apps.packetTracer.enable = true
# y seguir el README (sección Cisco Packet Tracer) para el prefetch del .deb.
#
# Re-pin del .deb: nixpkgs pineó el tarball "900" original (3ZrA1...), pero
# NetAcad ya solo sirve el 9.0.1: el .deb prefetecheado el 2026-08-17 es
# Version: 9.0.1 (verificado con dpkg-deb). hash real (MODO FLAT, el que
# requireFile espera; el hash NAR de `nix hash path` NO sirve):
#   sha256-NoPdh+d5iFNyrpo1wabllNEvST5knnxpdAhynBRZR5s=
# Si Cisco re-empaqueta: correr `nix-prefetch-url --type sha256
# file:///ruta/CiscoPacketTracer_900_Ubuntu_64bit.deb`, tomar el hash impreso
# y comprobar con `nix build pkgs.requireFile {...}` antes de pegarlo aquí
# (misma filosofia que unstableFixesOverlay en flake.nix).
#
# El 9.0.1 NO es un AppImage estandar: es un ELF (stub) seguido del squashfs
# con el árbol de la app, SIN el footer "AI\x02" que appimageTools espera
# (por eso el extractor de nixpkgs lo rechaza con "Not an AppImage file", y su
# wrapper tampoco puede ejecutarlo: el stub pide /lib64/ld-linux inexistente).
# Se extrae el squashfs a mano: el superblock "hsqs" es la ÚLTIMA ocurrencia
# en el archivo (la primera es una coincidencia falsa en el stub).
# El launcher del propio .deb es el contrato de runtime:
#   export LD_LIBRARY_PATH=/opt/pt/bin && cd opt/pt/bin && ./PacketTracer
# (el AppRun del AppImage además copia la app a ~/.local/.packettracer — se
# ignora: el store es de solo lectura y el plan es el launcher directo).
{ config, pkgs, lib, ... }:

let
  # El AppImage trae Qt6 adentro, pero NO las libs del "sistema" (Mesa/GL,
  # X11/xcb, glib/dbus/udev, fontconfig/harfbuzz, NSS, zstd/png/jpeg/tiff,
  # pulse...): en Ubuntu viven en el OS, en el store hay que dárselas. Lista
  # sacada de la salida de `ldd` (las 34 faltantes); mismo patron que
  # omnetpp.nix.
  systemLibs = with pkgs; lib.makeLibraryPath [
    stdenv.cc.cc.lib
    libGL
    libdrm
    zlib
    zstd
    brotli
    libpng
    libjpeg
    libtiff
    fontconfig
    harfbuzz
    expat
    glib
    pcre2
    dbus
    systemdLibs
    libxkbcommon
    xorg.libxkbfile
    nspr
    nss
    libpulseaudio
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXtst
  ];

  pkg = pkgs.stdenvNoCC.mkDerivation {
    pname = "cisco-packet-tracer";
    version = "9.0.1";

    src = pkgs.requireFile {
      name = "CiscoPacketTracer_900_Ubuntu_64bit.deb";
      hash = "sha256-NoPdh+d5iFNyrpo1wabllNEvST5knnxpdAhynBRZR5s=";
      url = "https://www.netacad.com/resources/lab-downloads";
    };

    nativeBuildInputs = [
      pkgs.dpkg
      pkgs.squashfsTools
      pkgs.patchelf
      pkgs.makeWrapper
    ];

    # El .deb NO se desempaqueta con el unpackPhase por defecto (crea un árbol
    # "root/" que choca con la extracción manual del squashfs); todo se extrae
    # a mano en installPhase.
    dontUnpack = true;

    # El .deb se extrae, del AppImage se corta el squashfs y el árbol resultante
    # se instala completo en $out/opt. El binario (105MB, ELF dinámico con
    # interp de distro genérica) se re-apunta al loader del store: en NixOS no
    # existe /lib64/ld-linux-x86-64.so.2 y el arranque fallaría de una.
    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/share/applications \
        $out/share/icons/hicolor/48x48/apps

      # 1. del .deb al AppImage
      dpkg-deb -x $src $TMPDIR/deb
      APP=$TMPDIR/deb/opt/pt/packettracer.AppImage

      # 2. del AppImage al squashfs (ultima "hsqs" = superblock real)
      OFF=$(grep -abo "hsqs" "$APP" | tail -1 | cut -d: -f1)
      [ -n "$OFF" ] || { echo "sin superblock squashfs en $APP"; exit 1; }
      tail -c +$((OFF + 1)) "$APP" > $TMPDIR/pt.sqfs

      # 3. del squashfs al árbol de la app ($out/opt/)
      # -no-xattrs: el sandbox no puede escribir xattrs de SELinux y sin el flag
      # unsquashfs aborta el scan ("FATAL ERROR: dir_scan ... File exists").
      unsquashfs -no-xattrs -d $TMPDIR/approot $TMPDIR/pt.sqfs > /dev/null
      ROOT=$TMPDIR/approot
      cp -a $ROOT/opt $out/

      # 4. interp del binario -> loader del store
      patchelf --set-interpreter "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
        $out/opt/pt/bin/PacketTracer

      # 5. launcher: contrato del .deb + Wayland (Qt no mapea ventana bajo
      # Wayland nativo; xcb vía XWayland es el camino estable, igual que el
      # wrapper oficial de nixpkgs). QtWebEngine (Chromium) no tiene sandbox
      # setuid en NixOS: los user namespaces suelen bastar; si PT crashea con
      # "Failed to create sandbox", quitar el comentario de abajo.
      makeWrapper $out/opt/pt/bin/PacketTracer $out/bin/packettracer9 \
        --set QT_QPA_PLATFORM xcb \
        --prefix LD_LIBRARY_PATH : $out/opt/pt/bin \
        --prefix LD_LIBRARY_PATH : ${systemLibs} \
        --chdir $out/opt/pt/bin

      # 6. entradas de escritorio + icono (los nombres 9.0.1 viven en el AppDir)
      substitute $ROOT/CiscoPacketTracer-9.0.1.desktop \
        $out/share/applications/cisco-packet-tracer-9.desktop \
        --replace-fail "@EXEC_PATH@" "packettracer9" \
        --replace-fail "Icon=app" "Icon=cisco-packet-tracer-9"
      substitute $ROOT/CiscoPacketTracerPtsa-9.0.1.desktop \
        $out/share/applications/cisco-packet-tracer-ptsa-9.desktop \
        --replace-fail "@EXEC_PATH@" "packettracer9" \
        --replace-fail "Icon=app" "Icon=cisco-packet-tracer-9"
      install -Dm444 $ROOT/app.png \
        $out/share/icons/hicolor/48x48/apps/cisco-packet-tracer-9.png
      # mimetypes del AppImage (iconos de .pkt) si el AppDir los trae
      cp -r $ROOT/usr/share/icons/gnome/48x48/mimetypes \
        $out/share/icons/hicolor/48x48/ 2>/dev/null || true

      runHook postInstall
    '';

    # Self-check mínimo: el binario existe, el launcher enlaza y el interp quedó
    # re-apuntado (sin él, la app muere con "No such file or directory" al
    # cargar el PT_INTERP de la distro genérica).
    installCheckPhase = ''
      test -x $out/opt/pt/bin/PacketTracer
      test -x $out/bin/packettracer9
      patchelf --print-interpreter $out/opt/pt/bin/PacketTracer \
        | grep -q "^/nix/store" || { echo "interp sin re-apuntar"; exit 1; }
    '';
  };
in
{
  options.modules.apps.packetTracer.enable =
    lib.mkEnableOption "Cisco Packet Tracer (simulador de redes de Cisco)";

  config = lib.mkIf config.modules.apps.packetTracer.enable {
    environment.systemPackages = [ pkg ];
  };
}