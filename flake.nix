{
  description = "NixOS configuration — modular, cyberpunk, flake-driven";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Librería comunitaria de ~50k modelos SPICE (transistores, opamps, diodos,
    # lógica digital, manufacturas...). Se distribuye a todos los hosts como
    # pkgs.kicad-spice-library (overlay spiceLibraryOverlay, ver abajo) e
    # incluye los scripts de búsqueda/extracción. `flake = false`: repo de
    # datos puro (sin flake.nix propio). Actualizar modelos:
    # `nix flake update kicad-spice-library`.
    kicad-spice-library = {
      url = "github:kicad-spice-library/KiCad-Spice-Library";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, home-manager, kicad-spice-library, ... }:
    let
      system = "x86_64-linux";
      # Backend del portal RemoteDesktop para el remote input de KDE Connect en Hyprland.
      # kdeconnect (Wayland) inyecta teclado/raton via org.freedesktop.portal.RemoteDesktop
      # y ni wlr, gtk ni hyprland implementan esa interfaz; este shim la expone y reenvia
      # los eventos a zwlr_virtual_pointer/zwp_virtual_keyboard. No esta en nixpkgs.
      # Wiring: modules/desktop/hyprland-home.nix. Version 0.1.0, commit e86a0fb (2026-07-26).
      kdeconnectRemoteInputOverlay = final: prev: {
        hypr-kdeconnect-fix = prev.stdenv.mkDerivation {
          pname = "hypr-kdeconnect-fix";
          version = "0.1.0";
          src = prev.fetchFromGitHub {
            owner = "gfhdhytghd";
            repo = "hypr-kdeconnect-fix";
            rev = "e86a0fb17826cb8ea987665ded7428534e4a1a9d";
            hash = "sha256-VcXxVtlnkPjO6l0ky/n+0qa87Uc3c8hRM0twfgl+AiM=";
          };
          nativeBuildInputs = [ prev.cmake prev.pkg-config prev.wayland.dev prev.wayland-scanner ];
          buildInputs = [ prev.qt6.qtbase prev.libei prev.libxkbcommon prev.wayland ];
          # Daemon D-Bus sin QPA/QML: no necesita el wrapper de Qt.
          dontWrapQtApps = true;
          doCheck = true;
          meta = {
            description = "RemoteDesktop portal backend for KDE Connect remote input (Hyprland)";
            homepage = "https://github.com/gfhdhytghd/hypr-kdeconnect-fix";
            license = prev.lib.licenses.mit;
            maintainers = [ ];
            platforms = prev.lib.platforms.linux;
          };
        };
      };

      # Overlay de paquetes rotos en la punta de nixos-unstable: cuando el canal
      # pinna un hash que ya no coincide con el tarball real (GitHub re-genero el
      # tarball del tag, PyPI re-subio el sdist), un paquete bloquea TODO el
      # toplevel del sistema. En vez de esperar al fix upstream, se re-pinea el
      # hash localmente desde el fix de master (misma filosofia que un PKGBUILD
      # de AUR en Arch: paquete roto de upstream => parche local, sin esperar).
      # ponytail: techo conocido — cuando nixos-unstable publique el fix, el
      # override es redundante e inofensivo (mismo hash => misma derivacion);
      # borrarlo para no arrastrar mantenimiento muerto.
      unstableFixesOverlay = final: prev: let
        # Re-pinea SOLO el hash del source de nanoemoji al valor real del tarball
        # (el que el master de nixpkgs usa hoy). El resto de la derivación queda
        # igual; fetchFromGitHub es overridable.
        fixNanoemoji = p: p.overrideAttrs (old: {
          src = old.src.override {
            hash = "sha256-FysyKC01XBnRiur5RR9fcsTxQqE8x0JJHSoe3q6JtKc=";
          };
        });
      in {
        # jetbrains-mono (fuente de ${pkgs.jetbrains-mono}) construye con
        # python313Packages.gftools -> nanoemoji. Sin tocar python313Packages el
        # override no surte efecto (visto en la practica: hash mismatch persiste).
        nanoemoji = fixNanoemoji prev.nanoemoji;
        python313Packages = prev.python313Packages.overrideScope (pfinal: pprev: {
          nanoemoji = fixNanoemoji pprev.nanoemoji;
        });
        python3Packages = prev.python3Packages.overrideScope (pfinal: pprev: {
          nanoemoji = fixNanoemoji pprev.nanoemoji;
        });
      };

      # Librería SPICE de la comunidad (~50k modelos) como paquete de datos:
      # copia el repo a $out/share/kicad-spice-library y empaqueta los buscador
      # `spice-find` (buscar) y `spice-get` (buscar + extraer al proyecto). El
      # repo original no es un build, solo datos + scripts.
      # Se parchea el GUI (form_spice.py) para Linux: upstream escribe
      # config.json JUNTO al script (store = solo lectura) y trae rutas Windows
      # de fábrica (D:/... crashea el __init__ al hacer makedirs del output).
      # ponytail: techo conocido — si upstream arregla Linux, quitar el parche.
      spiceLibraryOverlay = final: prev: let
        spiceSrc = kicad-spice-library;
        spicePython = final.python3.withPackages (ps: [ ps.termcolor ]);
      in {
        kicad-spice-library = final.runCommand "kicad-spice-library" {
          nativeBuildInputs = [ final.makeWrapper ];
        } ''
          mkdir -p $out/share/kicad-spice-library $out/bin
          cp -r ${spiceSrc}/Models ${spiceSrc}/Scripts ${spiceSrc}/Supported.pickle \
            ${spiceSrc}/Supported.txt ${spiceSrc}/README.md ${spiceSrc}/LICENSE \
            $out/share/kicad-spice-library/
          makeWrapper ${spicePython}/bin/python3 $out/bin/spice-find \
            --add-flags "$out/share/kicad-spice-library/Scripts/check_supported.py"
          # spice-get: buscador + extractor en un comando, pensado para correr
          # DENTRO de la carpeta de un proyecto KiCad. Elige la misma variante
          # recomendada que el GUI (Manufacturer > spice_complete > uncategorized),
          # sane los params metadata que ngspice rechaza (mfg=/type=/SRC=/SYM=),
          # verifica la carga real en ngspice y acumula en localSpice.lib sin
          # duplicar modelos ya extraidos.
          mkdir -p $out/libexec
          cat > $out/libexec/spice-get.py <<'PYEOF'
#!/usr/bin/env python3
"""spice-get: extrae un modelo de la libreria SPICE al proyecto actual.

Uso: spice-get <modelo> [<modelo> ...]   (correr dentro del proyecto KiCad)

Busca <modelo> en la libreria comunitaria (~50k modelos), elige la variante
recomendada (Manufacturer > spice_complete > uncategorized) y la extrae a
localSpice.lib en el directorio actual. Si el modelo ya esta definido en
localSpice.lib, no lo duplica.

Flujo tipico en un proyecto:
  spice-find lm741         # confirmar que existe y ver variantes
  spice-get lm741          # extrae a localSpice.lib del proyecto
  # en KiCad: directiva SPICE ".include localSpice.lib" + nombre del modelo
  # en el campo SPICE model del simbolo (o Model de su prop. SPICE).

Ademas, spice-get sane lo que el repo upstream no: quita parametros metadata
de PSpice/LTspice que ngspice rechaza (mfg=, type=, SRC=, SYM=), verifica que
el modelo carga de verdad en ngspice (lo usa en un .op minimo) y si la
variante top falla, cae a la siguiente.
"""
import os
import pickle
import re
import subprocess
import sys
import tempfile

LIB_ROOT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.realpath(__file__))),
    "share",
    "kicad-spice-library",
)
SCRIPTS_DIR = os.path.join(LIB_ROOT, "Scripts")
PICKLE = os.path.join(LIB_ROOT, "Supported.pickle")
EXTRACTOR = os.path.join(SCRIPTS_DIR, "extractModels.pl")
OUTPUT = "localSpice.lib"


def priority(path):
    if path.startswith("Manufacturer"):
        return 0
    if "spice_complete" in path:
        return 1
    return 2


def already_defined(model, text):
    # La definicion extraida puede diferir en mayusculas del nombre pedido.
    pattern = r"^\.(model|subckt)\s+" + re.escape(model) + r"\b"
    return re.search(pattern, text, re.IGNORECASE | re.MULTILINE) is not None


def extract_manual(model, path):
    # Fallback cuando extractModels.pl no matchea (p.ej. librerias que cierran
    # el .subckt con .ends sin nombre). Lee el .lib original con regex simple,
    # case-insensitive, y cubre continuaciones "+" de los .model.
    lib_path = os.path.join(LIB_ROOT, "Models", path)
    with open(lib_path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()
    name = re.escape(model)
    sub = re.search(
        r"^\.subckt\s+" + name + r"\b.*?(?=^\.ends\b)",
        text,
        re.IGNORECASE | re.DOTALL | re.MULTILINE,
    )
    if sub:
        return sub.group(0) + "\n.ends\n"
    mod = re.search(
        r"^\.model\s+" + name + r"\b[^\n]*(?:\n\+\s*[^\n]*)*",
        text,
        re.IGNORECASE | re.MULTILINE,
    )
    if mod:
        return mod.group(0) + "\n"
    return None


def sanitize(body):
    # Quita params metadata con valor no numerico (mfg=Philips, type=NPN,
    # SRC=..., SYM=...): ngspice los rechaza y descarta el modelo completo.
    # Los valores numericos (100P, 1E-14, .7, -2.5m) no se tocan. El bucle
    # cubre varios junk encadenados (mfg=A SRC=B, ...) que un solo pase deja.
    pattern = r"\s*,\s*\w+=[A-Za-z][^,)]*|\s+\w+=[A-Za-z][^,)]*(?=\s*[,)])"
    prev = None
    while prev != body:
        prev = body
        body = re.sub(pattern, "", body)
    return body


def guess_usage(model, body):
    # Dispositivo de prueba minimo segun el tipo de definicion extraida.
    m = re.search(r"^\.model\s+\S+\s+(\S+)", body, re.MULTILINE)
    if m:
        t = m.group(1).upper()
        if t == "D":
            return "D1 1 0 {}".format(model)
        if t in ("NPN", "PNP"):
            return "Q1 1 1 0 {}".format(model)
        if t in ("NJF", "PJF"):
            return "J1 1 1 0 {}".format(model)
        if t in ("NMOS", "PMOS"):
            return "M1 1 1 0 0 {}".format(model)
        return None  # tipo desconocido: confiar en sanitize
    m = re.search(r"^\.subckt\s+\S+(.*)$", body, re.MULTILINE)
    if m:
        pins = [w for w in m.group(1).split() if not w.startswith("*")]
        if pins:
            nodes = " ".join("n{}".format(i) for i in range(len(pins)))
            return "X1 {} {}".format(nodes, model)
    return None


def model_loads(model, body):
    # Verifica que el modelo realmente carga en ngspice usandolo en un .op
    # minimo: los modelos con params basura se descartan SILENCIOSAMENTE y el
    # error solo aparece al usarlos ("can't find model").
    usage = guess_usage(model, body)
    if usage is None:
        return True
    fd, path = tempfile.mkstemp(suffix=".cir")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(body + "\n" + usage + "\n.op\n.end\n")
        r = subprocess.run(["ngspice", "-b", path], capture_output=True, text=True)
    finally:
        os.unlink(path)
    out = (r.stdout + r.stderr).lower()
    bad = (
        "can't find model" in out
        or "undefined parameter" in out
        or "expression err" in out
        or "error" in out
    )
    return not bad


def main(argv):
    if len(argv) < 2:
        print("Uso: spice-get <modelo> [<modelo> ...]  (dentro del proyecto)")
        return 1
    with open(PICKLE, "rb") as f:
        supported = pickle.load(f)

    existing = ""
    if os.path.exists(OUTPUT):
        with open(OUTPUT, "r", encoding="utf-8", errors="replace") as f:
            existing = f.read()

    for raw in argv[1:]:
        model = raw.lower()
        if model not in supported:
            print("{}: no encontrado. Prueba 'spice-find {}' para ver sugerencias.".format(raw, raw))
            continue
        if already_defined(model, existing):
            print("{}: ya esta en {}. Nada que hacer.".format(model, OUTPUT))
            continue
        candidates = sorted(supported[model], key=priority)
        chosen = None
        body = None
        for cand in candidates:
            cand = cand.replace("\\", "/")
            try:
                out = subprocess.run(
                    ["perl", EXTRACTOR, "{}#{}".format(model, cand)],
                    cwd=SCRIPTS_DIR,
                    capture_output=True,
                    check=True,
                    text=True,
                ).stdout
            except subprocess.CalledProcessError:
                continue
            b = out.split("\n*\n", 1)[1] if "\n*\n" in out else out
            if not re.search(r"^\.(model|subckt)\s", b, re.MULTILINE):
                # extractModels.pl no siempre matchea (librerias que cierran
                # con .ends sin nombre): fallback con regex sobre el .lib.
                b = extract_manual(model, cand) or ""
            b = sanitize(b.strip())
            if b and model_loads(model, b):
                chosen, body = cand, b
                break
        if body is None:
            print("{}: ninguna variante usable. Usa .include directo del .lib o revisa spice-find.".format(model))
            continue
        with open(OUTPUT, "a", encoding="utf-8") as f:
            f.write("* {} (extraido por spice-get desde {})\n".format(model, chosen))
            f.write(body + "\n")
        existing += body + "\n"
        print("{}: extraido de '{}' -> {} en {}".format(model, chosen, OUTPUT, os.getcwd()))

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
PYEOF
          makeWrapper ${spicePython}/bin/python3 $out/bin/spice-get \
            --add-flags "$out/libexec/spice-get.py"
          substituteInPlace $out/share/kicad-spice-library/Scripts/form_spice.py \
            --replace-fail "os.path.join(os.path.dirname(__file__), 'config.json')" \
              "os.path.expanduser('~/.config/kicad-spice/form_spice.json')" \
            --replace-fail "'scripts_dir': r'D:/kicad/library/KiCad-Spice-Library/Scripts'," \
              "'scripts_dir': '$out/share/kicad-spice-library/Scripts'," \
            --replace-fail "'output_dir':  r'D:/kicad/library/my-lib'" \
              "'output_dir':  os.path.expanduser('~/spice-output')"
        '';
      };

      # Tema de cursor Material Bibata (SakibShahariar/material-bibata-cursor),
      # variante Deep Blue (Material 3: cuerpo oscuro + contorno azul vibrante),
      # como paquete de datos: extrae solo la carpeta del tema deep blue del
      # tar.gz precompilado del release v1.3.0 (bibata-material-dark, ya trae
      # cursors/*.xcur + index.theme + symlinks, no se construye nada) y la
      # copia a $out/share/icons/Bibata-Material-Deep-Blue. Estándar Xcursor lo
      # recoge cualquier app. Se fuerza via home-manager pointerCursor
      # (theme-base.nix).
      bibataCursorOverlay = final: prev: {
        bibata-material-deep-blue = final.runCommand "bibata-material-deep-blue" {
          nativeBuildInputs = [ prev.gnutar ];
        } ''
          mkdir -p $out/share/icons
          tar xzf ${prev.fetchurl {
            url = "https://github.com/SakibShahariar/material-bibata-cursor/releases/download/v1.3.0/bibata-material-dark-v1.3.0.tar.gz";
            hash = "sha256-8M/aOIy+b819lQemyKIaAfYKjCgmDIO4WzLyB3G752s=";
          }} -C $out/share/icons bibata-material-dark-v1.3.0/Bibata-Material-Deep-Blue
          mv $out/share/icons/bibata-material-dark-v1.3.0/Bibata-Material-Deep-Blue \
             $out/share/icons/Bibata-Material-Deep-Blue
          rm -rf $out/share/icons/bibata-material-dark-v1.3.0
        '';
      };

      mkHost = hostName: hostModules: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Overlay visible en todos los modulos y en home-manager (useGlobalPkgs=true).
          { nixpkgs.overlays = [ kdeconnectRemoteInputOverlay unstableFixesOverlay spiceLibraryOverlay bibataCursorOverlay ]; }
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.yovick = import ./home/default.nix;
            };
          }

          ./modules/core/nix-optimization.nix
        ] ++ hostModules;
      };
    in
    {
      nixosConfigurations = {
        pc = mkHost "pc" [ ./hosts/pc/configuration.nix ];
        laptop = mkHost "laptop" [ ./hosts/laptop/configuration.nix ];
        server = mkHost "server" [ ./hosts/server/configuration.nix ];
        vm = mkHost "vm" [ ./hosts/vm/configuration.nix ];
      };
    };
}
