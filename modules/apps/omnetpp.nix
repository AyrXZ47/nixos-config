# OMNeT++ 6.4.0 (simulador de redes discrete-event, ing. telecomunicaciones).
#
# No esta en nixpkgs (se removio hace anios y los tarballs prebuilt ya no traen
# binarios: 6.1+ es solo fuente). Se compila desde el tarball oficial siguiendo
# el entorno de build que OMNeT++ mismo declara para NixOS (.opp_shell/flake.nix,
# incluido en el tarball): clangStdenv + Qt6, sin hardening fortify.
#
# Desviaciones del entorno oficial:
#  - WITH_OSG=no: Qtenv 3D necesita libosgQt, que nixpkgs NO empaqueta
#    (openscenegraph sin el plugin Qt). La vista 2D cubre el curso.
#  - python/requirements.txt relajado a "pandas >=1.0.0": nixpkgs solo trae
#    pandas 3.x y el chequeo de configure pide <3.0.0. Solo afecta al modulo
#    scave del IDE (analisis de resultados); las simulaciones no lo usan.
#
# El arbol es in-place (no hay make install): se copia la fuente a $out y se
# configura/compila ahi, asi OMNETPP_ROOT queda apuntando al path final del
# store. autoPatchelfHook re-enlaza binarios y JRE del IDE contra las libs de
# nixpkgs (los del tarball son de Ubuntu).
{ config, pkgs, lib, ... }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.packaging
    ps.pip
    ps.matplotlib
    ps.numpy
    ps.pandas
    ps.scipy
    ps.ipython
  ]);

  # Qt6 (Qtenv) + Python embebido (pyeval) + dependencias del IDE (Eclipse:
  # GTK/webkit) y de INET (z3, ffmpeg) — misma lista que el flake oficial.
  deps = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    elfutils
    glib
    qt6.qtbase
    qt6.qtwayland
    qt6.qtsvg
    libGL
    z3
    ffmpeg-headless
    pythonEnv
    gtk3
    # fallback SWT de Eclipse (swt-pi4) si el de GTK3 falla
    gtk4
    glib-networking
    libsecret
    cairo
    freetype
    fontconfig
    libxtst
    libx11
    libxrender
    adw-gtk3
    gsettings-desktop-schemas
    shared-mime-info
    webkitgtk_4_1
    alsa-lib
    atk
    cups
    expat
    dbus
    libgbm
    libxkbcommon
    nspr
    nss
    pango
    udev
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
  ];

  omnetppLibPath = pkgs.lib.makeLibraryPath deps;

  omnetpp = pkgs.clangStdenv.mkDerivation {
    pname = "omnetpp";
    version = "6.4.0";

    src = pkgs.fetchurl {
      url = "https://github.com/omnetpp/omnetpp/releases/download/omnetpp-6.4.0/omnetpp-6.4.0-linux-x86_64.tgz";
      sha256 = "sha256-LdLPvTiOUOhD9XE3FvBl6Hjfe7EEtp80NfdAs3sh1Fk=";
    };

    nativeBuildInputs = with pkgs; [
      gnumake
      autoconf
      bison
      flex
      perl
      pkg-config
      xdg-utils
      swig
      lld
      patchelf
      makeWrapper
      unzip
      zip
      autoPatchelfHook
    ];

    buildInputs = deps;

    hardeningDisable = [ "fortify" ];

    # Sin wrapper Qt de nixpkgs: el arbol OMNeT++ se usa in-place (sus bin
    # scripts resuelven el root ellos mismos) y las rpaths las pone
    # autoPatchelfHook.
    dontWrapQtApps = true;

    # Todo ocurre dentro de $out: configure exige que el root de OMNeT++
    # (derivado del dir del script) coincida con $OMNETPP_ROOT del entorno.
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -a . $out/
      cd $out
      sed -i 's/^WITH_OSG=yes/WITH_OSG=no/' configure.user
      sed -i 's/pandas >=1.0.0, <3.0.0/pandas >=1.0.0/' python/requirements.txt
      export __omnetpp_root_dir=$out
      export PATH=$out/bin:$PATH
      export PYTHONPATH=$out/python:$PYTHONPATH
      export OMNETPP_IMAGE_PATH=$out/images:$OMNETPP_IMAGE_PATH
      export QT_SELECT=6
      export QT_LOGGING_RULES='*.warning=false;qt.qpa.*=false'
      export OMNETPP_RELEASE=$(cat Version)
      # Herramientas intermedias del build (opp_msgtool, opp_msgc...) corren
      # apenas se compilan y necesitan libstdc++/Qt/libdw en runtime: mismo
      # LD_LIBRARY_PATH que el shellHook del flake oficial de OMNeT++.
      export LD_LIBRARY_PATH="${omnetppLibPath}:$LD_LIBRARY_PATH"
      # SWT del IDE: sus nativos van DENTRO de un jar (autoPatchelf no los ve)
      # y son de Ubuntu (sin rpath): System.loadLibrary falla en NixOS
      # ("Failed to load swt-pi3"). Se les anade rpath a las deps del store y
      # se reempaqueta el jar.
      swtjar=$(ls $out/ide/plugins/org.eclipse.swt.gtk.linux.x86_64_*.jar)
      swttmp=$(mktemp -d)
      cd $swttmp
      unzip -q "$swtjar"
      for f in *.so; do
        patchelf --add-rpath "${omnetppLibPath}" "$f"
      done
      zip -q -o "$swtjar" *.so
      cd -
      rm -rf "$swttmp"
      # Shebangs #!/usr/bin/env fallan en el sandbox (no hay /usr) y en NixOS
      # (no hay /usr/bin/env): se reescriben a los interpretes del store.
      patchShebangs $out
      # xdg-desktop-menu (utils build) intenta escribir en $HOME, que en el
      # sandbox es /homeless-shelter (no escribible).
      export XDG_CONFIG_HOME=$TMPDIR/xdg
      ./configure
      make -j$NIX_BUILD_CORES MODE=release
      # artefactos de compilacion (.o): innecesarios en runtime
      rm -rf $out/out
      # JNA del IDE empaqueta libs nativas de TODOS los OS (freebsd, sunos,
      # dragonflybsd, linux-arm...): autoPatchelf fallaria en los no-x86_64
      # (piden libc.so.8 de FreeBSD). En runtime solo se usa linux-x86-64.
      find $out -path '*com/sun/jna/*' -type f ! -path '*linux-x86-64*' -delete
      # Atajos auto-generados del make (install-shortcuts): apuntan a "setenv
      # opp_ide"/"setenv bash", que en NixOS intenta "nix develop .opp_shell"
      # (descarga de inputs + error si hay otro nix corriendo). Se borran y se
      # empaqueta una entrada propia debajo (share/applications/omnetpp.desktop).
      rm -f $out/omnetpp-6.4.0-{ide,shell}.desktop
      # setenv: el paquete ya trae todo el entorno horneado (rpaths y PATH van
      # en el store), el bootstrap de "nix print-dev-env .opp_shell" es
      # innecesario y rompe (mismo error de eval-cache). Ambas ramas NixOS del
      # script (sourced y ejecutado) se desactivan.
      sed -i 's|if \[\[ -f /etc/NIXOS && "\$name" != "opp_shell" \]\]; then|if false; then|' $out/setenv
      sed -i 's|if \[\[ -f /etc/NIXOS \]\]; then|if false; then|' $out/setenv
      # Un solo icono: el IDE, apuntando al launcher envuelto (envs GTK/schemas).
      mkdir -p $out/share/applications
      cat > $out/share/applications/omnetpp.desktop <<EOF
[Desktop Entry]
Type=Application
Name=OMNeT++ IDE
GenericName=Discrete event simulator IDE
Exec=omnetpp
Path=$out
Icon=$out/images/logo/logo128.png
Categories=Development;IDE;
EOF
      runHook postInstall
    '';

    # Self-check: sin las rpaths correctas opp_run no encuentra liboppsim y
    # esto falla al instante (los binarios llevan rpath a $out/lib desde el
    # link; autoPatchelfHook cubre los del IDE).
    installCheckPhase = ''
      $out/bin/opp_run -h >/dev/null 2>&1
    '';

    # Wrapper del launcher del IDE: sin estos envs el GTK del Eclipse no
    # encuentra schemas/modulos gio y el login al IDE se ve generico o falla
    # el TLS de glib-networking.
    postFixup = ''
      wrapProgram $out/bin/omnetpp \
        --prefix GIO_EXTRA_MODULES : "${pkgs.glib-networking}/lib/gio/modules" \
        --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.adw-gtk3}/share/gsettings-schemas/${pkgs.adw-gtk3.name}"
    '';
  };
in
{
  environment.systemPackages = [ omnetpp ];
}
