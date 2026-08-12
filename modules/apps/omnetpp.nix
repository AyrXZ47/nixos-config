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

  # Lib path del IDE (rpath de los nativos SWT + LD_LIBRARY_PATH del build).
  # OJO: NO usar LD_LIBRARY_PATH en el wrapper del IDE: verificado que con
  # CUALQUIER path puesto ahi, gtk_init_check falla ("Cannot open display").
  # El runtime del IDE se cubre con rpaths (autoPatchelf + parche del jar SWT)
  # y con nix-ld abajo (binarios sin parchear).
  # Dependencias del IDE para nix-ld (misma lista que ideDependencies del
  # flake oficial .opp_shell de OMNeT++).
  ideDeps = with pkgs; [
    adw-gtk3
    fontconfig
    freetype
    glib
    glib-networking
    gtk3
    gsettings-desktop-schemas
    shared-mime-info
    webkitgtk_4_1
    libx11
    libxrender
    libxtst
    zlib
    alsa-lib
    atk
    cairo
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
      # OJO: borrar solo los libjnidispatch.so foraneos; el directorio del
      # bundle contiene TAMBIEN las clases (com/sun/jna/Pointer.class) — un
      # borrado mas amplio deja el IDE sin JNA (core.net/egit mueren y el
      # workbench aborta sin abrir ventana).
      find $out -name 'libjnidispatch.so' ! -path '*linux-x86-64*' -delete
      # Atajos auto-generados del make (install-shortcuts): apuntan a "setenv
      # opp_ide"/"setenv bash", que en NixOS intenta "nix develop .opp_shell"
      # (descarga de inputs + error si hay otro nix corriendo). Se borran y se
      # empaqueta una entrada propia debajo (share/applications/omnetpp.desktop).
      rm -f $out/omnetpp-6.4.0-{ide,shell}.desktop
      # p2 del IDE: el profile pide org.eclipse.e4.ui.swt.gtk (fragment que el
      # tarball NO incluye — bug de empaquetado upstream). El reconciler de
      # p2 planea instalarlo al arrancar (lo ve en profile y en artifacts.xml),
      # el archivo no existe y aborta el IDE ("Application error"). Se borra
      # de los snapshots del profile (elemento con body: <filter> y </unit>),
      # de bundles.info (de donde reconcilia el simpleconfigurator) y del
      # cache de artefactos (donde esta listado pero sin archivo).
      for p in $out/ide/p2/org.eclipse.equinox.p2.engine/profileRegistry/DefaultProfile.profile/*.profile.gz; do
        zcat "$p" | sed -e "/<unit id='org.eclipse.e4.ui.swt.gtk'/,/<\/unit>/d" -e "/name='org.eclipse.e4.ui.swt.gtk' range/,/<\/required>/d" | gzip > "$p.tmp"
        mv "$p.tmp" "$p"
      done
      sed -i '/^org.eclipse.e4.ui.swt.gtk,/d' $out/ide/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info
      sed -i "/<artifact classifier='osgi.bundle' id='org.eclipse.e4.ui.swt.gtk'/,/<\/artifact>/d" $out/ide/artifacts.xml
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
    # GDK_BACKEND=x11: SWT GTK3 no mapea ventana bajo Wayland nativo
    # (el proceso queda vivo pero no aparece nada); XWayland es el camino
    # estandar de Eclipse.
    postFixup = ''
      # El workspace default del make apunta a samples/ (store, read-only):
      # el IDE fallaba al crear el workspace ahi. Se reescribe a un dir
      # escribible del usuario ($HOME se expande en runtime).
      sed -i 's|DEFAULT_WORKSPACE_ARGS="-vmargs -Dosgi.instance.area.default=\$IDEDIR/../samples"|DEFAULT_WORKSPACE_ARGS="-vmargs -Dosgi.instance.area.default=$HOME/omnetpp-workspace"|' $out/bin/opp_ide
      # El IDE corre por el camino oficial de OMNeT++ para NixOS (su flake
      # .opp_shell): nix-ld con NIX_LD/NIX_LD_LIBRARY_PATH para los binarios
      # sin parchear (JRE, natives dentro de jars). Sin LD_LIBRARY_PATH:
      # rompe gtk_init_check.
      wrapProgram $out/bin/omnetpp \
        --set GDK_BACKEND x11 \
        --set NIX_LD "$(cat ${pkgs.stdenv.cc}/nix-support/dynamic-linker)" \
        --set NIX_LD_LIBRARY_PATH "${pkgs.lib.makeLibraryPath ideDeps}" \
        --prefix GIO_EXTRA_MODULES : "${pkgs.glib-networking}/lib/gio/modules" \
        --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.adw-gtk3}/share/gsettings-schemas/${pkgs.adw-gtk3.name}"
    '';
  };
in
{
  # nix-ld: el camino oficial de OMNeT++ para NixOS (su flake .opp_shell lo
  # requiere para correr el IDE sin parchear). Loader shim para binarios con
  # interpretador de distro generica: mapea las libs a nixpkgs via
  # NIX_LD_LIBRARY_PATH (lo pone el wrapper de bin/omnetpp).
  programs.nix-ld.enable = true;

  environment.systemPackages = [ omnetpp ];
}
