{ config, pkgs, lib, ... }:

let
  # ponytail: mixxx crashea en el file dialog (QGtk3Theme → g_settings_set_property abort).
  # Trigger: QT_QPA_PLATFORMTHEME=gtk3 global. Desactivamos el platform theme solo para
  # mixxx; su theming no depende de él (qt.style/kdeglobals lo cubren).
  #
  # Mixxx 2.5.x tiene una fuga de memoria durante el análisis de librería (aquí
  # llegó a ~53 GB de RSS → OOM global y 30s de congelamiento por el thrash de
  # swap; en análisis normal con 6k canciones no pasa de unos GB). Se lanza
  # dentro de un cgroup con MemoryMax=8G: si vuelve a fugarse, el OOM del
  # cgroup lo mata limpio y rápido, sin tocar al resto del sistema. Subir el
  # límite en este archivo si un uso legítimo lo llegara a necesitar.
  # KiCad completo: librerias, 3D, scripting, i18n y el simulador SPICE embebido
  # (libngspice: KICAD_SPICE=true con withNgspice por defecto en Linux) ya vienen
  # en el default de nixpkgs. Los addons oficiales (kikit: panelizado y gerber,
  # kikit-library) no, y el PCM de KiCad no puede instalarlos en el store de
  # solo lectura; se montan con el override `addons` de nixpkgs.
  # NOTA: el simulador embebido NO expone el binario `ngspice` en el PATH; el
  # CLI standalone va en systemPackages (bloque Engineering & Simulation).
  kicad = pkgs.kicad.override {
    addons = with pkgs.kicadAddons; [ kikit kikit-library ];
  };
  mixxx = pkgs.symlinkJoin {
    name = "mixxx";
    paths = [ pkgs.mixxx ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      mv $out/bin/mixxx $out/bin/.mixxx-wrapped
      makeWrapper ${pkgs.systemd}/bin/systemd-run $out/bin/mixxx \
        --unset QT_QPA_PLATFORMTHEME \
        --add-flags "--user --scope --quiet -p MemoryMax=8G" \
        --add-flags "$out/bin/.mixxx-wrapped"
    '';
  };
  # Shotcut busca `ffmpeg` y `whisper-cli` EN EL MISMO DIRECTORIO que su propio
  # binario (applicationDirPath): subtitlesdock.cpp:666 y settings.cpp:2049.
  # En nixpkgs no viven ahí, así que "Import Subtitles" dice "ffmpeg not found"
  # y el Speech-to-Text invoca al propio shotcut (que rechaza los flags de
  # whisper). Fix: overrideAttrs que los instala DENTRO del mismo $out del
  # paquete (NOTA: symlinkJoin NO sirve — Qt resuelve applicationDirPath al
  # destino real del symlink y apunta al store plano, sin los binarios).
  # REGLA GENERAL GPU: whisper-cpp va con vulkanSupport (RX 7600).
  # ponytail: si nixpkgs algún día empaqueta shotcut con ambos adyacentes,
  # borrar el override y volver al paquete plano.
  whisperVulkan = pkgs.whisper-cpp.override { vulkanSupport = true; };
  shotcut = pkgs.shotcut.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      ln -s ${pkgs.ffmpeg_8}/bin/ffmpeg $out/bin/ffmpeg
      ln -s ${whisperVulkan}/bin/whisper-cli $out/bin/whisper-cli
    '';
  });
  # Logisim-Evolution: dark mode forzado de forma declarativa. La Look and Feel
  # vive en java.util.prefs (Preferences.userNodeForPackage(Main) = nodo
  # /com/cburch/logisim -> ~/.java/.userPrefs/com/cburch/logisim/prefs.xml), no
  # en el config de NixOS, y los temas oscuros de 4.1.0 vienen a medio arreglar.
  # El wrapper siembra la preferencia (FlatLaf Dark + canvas/grid oscuros) en
  # cada lanzamiento y luego exec al binario real: así el dark mode es inmune a
  # que el humano o un flush del propio Logisim lo revierta.
  # ponytail: si una versión futura arregla los temas oscuros y el usuario se
  # cansa del dark forzado, borrar este wrapper y usar Preferences -> Window ->
  # Look and Feel del GUI.
  logisimDarkSeed = pkgs.writeTextFile {
    name = "logisim-dark-seed.py";
    text = ''
import os
import xml.etree.ElementTree as ET

d = os.path.expanduser("~/.java/.userPrefs/com/cburch/logisim")
os.makedirs(d, exist_ok=True)
f = os.path.join(d, "prefs.xml")
# OJO: java.util.prefs (JDK moderno) guarda <map MAP_XML_VERSION="1.0"> con
# doctype EXACTO y colores como int ARGB con signo (0xFF000000|rgb en signed
# 32-bit), NO hex — Preferences.getInt hace Integer.parseInt (base 10) y un
# "0x..." lanzaria y caeria al default. ElementTree no puede emitir el doctype,
# asi que se serializa a mano en el formato byte-a-byte que escribe el JVM.
prefs = {
    "LookAndFeel": "com.formdev.flatlaf.FlatDarkLaf",
    "canvasBgColor": "-13948117",  # 0xFF2B2B2B
    "gridBgColor": "-13948117",
    "gridDotColor": "-9539986",  # 0xFF6E6E6E
    "gridZoomedDotColor": "-9539986",
    "componentColor": "-1",  # 0xFFFFFFFF
    "componentSecondaryColor": "-1",
    "componentGhostColor": "-7697782",  # 0xFF8A8A8A
    "componentIconColor": "-1",
    # verde claro: el SimFalseColor default (0x006400) es invisible sobre canvas oscuro
    "SimFalseColor": "-16733696",  # 0xFF00AA00
}


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace('"', "&quot;")


entries = {}
if os.path.exists(f):
    try:
        for e in ET.parse(f).getroot():
            if e.tag == "entry":
                entries[e.get("key")] = e.get("value")
    except Exception:
        entries = {}
entries.update(prefs)
lines = [
    '<?xml version="1.0" encoding="UTF-8" standalone="no"?>',
    '<!DOCTYPE map SYSTEM "http://java.sun.com/dtd/preferences.dtd">',
    '<map MAP_XML_VERSION="1.0">',
]
for k in sorted(entries):
    lines.append('  <entry key="{}" value="{}"/>'.format(esc(k), esc(entries[k])))
lines.append("</map>")
with open(f, "w") as out:
    out.write("\n".join(lines) + "\n")
    '';
  };
  logisimDark = pkgs.symlinkJoin {
    name = "logisim-evolution";
    paths = [ pkgs.logisim-evolution ];
    postBuild = ''
      # El .desktop e iconos del paquete original siguen en share/ (rofi los
      # encuentra porque Exec=logisim-evolution resuelve a este wrapper).
      mv $out/bin/logisim-evolution $out/bin/.logisim-evolution-real
      cat > $out/bin/logisim-evolution <<EOF
#!/bin/sh
${pkgs.python3}/bin/python3 ${logisimDarkSeed}
exec $out/bin/.logisim-evolution-real "\$@"
EOF
      chmod +x $out/bin/logisim-evolution
    '';
  };

  # Par de CLI que reemplaza el wizard/boton de Active-HDL en el flujo ghdl:
  #   vhdlnew <entidad>  -> crea <entidad>.vhd + tb_<entidad>.vhd (skeletons,
  #                         lo mismo que genera el "New VHDL File Wizard" del
  #                         IDE, sin el nombre con timestamp feo)
  #   vhdlrun <tb>       -> ghdl -a (todos los *.vhd menos tb_*) + -e + -r
  #                         (--vcd) + abre gtkwave. El equivalente de
  #                         "Compile All" + "Run Simulation" + wave window.
  # Flujillo por practica: vhdlnew mux2x1; editar ambos en el editor;
  # vhdlrun tb_mux2x1; mirar ondas; repetir.
  vhdlnew = pkgs.writeShellScriptBin "vhdlnew" ''
    set -euo pipefail
    if [ $# -ne 1 ]; then
      echo "uso: vhdlnew <nombre_entidad>" >&2
      exit 1
    fi
    n="$1"
    for f in "$n.vhd" "tb_$n.vhd"; do
      [ -e "$f" ] && { echo "$f ya existe" >&2; exit 1; }
    done
    cat > "$n.vhd" <<EOF
library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity $n is
  port (
    -- A   : in  STD_LOGIC;
    -- SEL : in  STD_LOGIC_VECTOR(1 downto 0);
    -- SAL : out STD_LOGIC_VECTOR(3 downto 0)
  );
end $n;

architecture arch of $n is
begin

end arch;
EOF
    cat > "tb_$n.vhd" <<EOF
library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity tb_$n is
end tb_$n;

architecture t of tb_$n is
  signal A   : STD_LOGIC := '1';  -- inicializa TUS entradas aqui
  signal SAL : STD_LOGIC_VECTOR(3 downto 0);
begin

  uut : entity work.$n port map (A => A, SAL => SAL);

  stim : process
  begin
    -- estimulos: cambia senales, espera y verifica. Ejemplo:
    --   SEL <= "00"; wait for 100 ns;
    --   assert SAL = "0001" report "fallo en 00" severity failure;
    wait for 100 ns;
    report "TODO: escribe aqui los estimulos y asserts";
    wait;
  end process;

end t;
EOF
    echo "creados: $n.vhd tb_$n.vhd"
  '';
  vhdlrun = pkgs.writeShellScriptBin "vhdlrun" ''
    set -euo pipefail
    if [ $# -lt 1 ]; then
      echo "uso: vhdlrun <tb_sin_.vhd> [fuente.vhd ...]   (DENTRO de la carpeta de la practica)" >&2
      exit 1
    fi
    tb="''${1%.vhd}"; tb="''${tb%.vcd}"   # tolera que le pases la extension
    shift
    if [ $# -gt 0 ]; then
      src=("$@")
    else
      src=()
      for f in *.vhd; do
        [ -e "$f" ] || break
        case "$f" in tb_*) continue ;; esac
        src+=("$f")
      done
      [ ''${#src[@]} -gt 0 ] || {
        echo "sin fuentes *.vhd en '$(pwd)'." >&2
        echo "vhdlrun se corre DENTRO de la carpeta de la practica, ej:" >&2
        echo "  cd arquitecturaDeComputadoras/practica02-demux1x4 && vhdlrun tb_demux1x4" >&2
        exit 1
      }
    fi
    ghdl -a "''${src[@]}" "$tb.vhd"
    ghdl -e "$tb"
    ghdl -r "$tb" --vcd="$tb.vcd"
    # Save file (.gtkw) con TODAS las senales del VCD para que GTKWave abra
    # mostrando las ondas de una vez (sin esto abre vacio y hay que arrastrar
    # senales a mano). Formato: seccion " Signals" con "signalname <ruta>"
    # (escalares) o "pattern <ruta>" (vectores); rutas = scopes del VCD unidos
    # por puntos, tomados del propio archivo para no duplicar la jerarquia.
    ${pkgs.python3}/bin/python3 - "$tb.vcd" > "$tb.gtkw" <<'PYEOF'
import sys
lines = ["[timestart] 0", "[size] 1600 900", "[pos_x] 0", "[pos_y] 0",
         "[sst_width] 260", "[signals_width] 240", "[sst_expanded] 1",
         "[sst_vpaned_height] 420", " Signals"]
scopes = []
for raw in open(sys.argv[1]):
    line = raw.strip()
    if line.startswith("$scope"):
        scopes.append(line.split()[2])
    elif line.startswith("$upscope"):
        if scopes:
            scopes.pop()
    elif line.startswith("$var"):
        p = line.split()
        kind = "signalname" if int(p[3]) == 1 else "pattern"
        lines.append(" {} {}.{}".format(kind, ".".join(scopes), p[4]))
print("\n".join(lines))
PYEOF
    # a workspace NUEVO consecutivo sin robar foco (ver guirun)
    guirun gtkwave "$tb.vcd" "$tb.gtkw" >/dev/null 2>&1 &
  '';
in
{
  imports = [ ./actual.nix ./omnetpp.nix ./python.nix ];

  # Actual Budget desktop app (todos los hosts; firefox sigue siendo el browser default)
  modules.apps.actual.enable = true;

  # Wireshark: el modulo de NixOS instala el wrapper setuid de dumpcap; el
  # usuario va en el grupo "wireshark" (ver modules/core/user.nix) para poder
  # capturar sin ser root.
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  services.ollama.enable = true;

  # Contexto 16k por defecto (el default de ollama es 4096): sesiones largas
  # llenaban el contexto y desactivaban MTP (decodificacion especulativa)
  # ("speculative decoding not supported by this context") -> caia de ~44 a ~18 t/s.
  # OJO (leccion R1): esta env var NO aplica a modelos con num_ctx propio en su
  # Modelfile (qwen3.8:27b fija 131072 y la ignora). El control real es el num_ctx
  # por request (cliente: Obsidian Copilot, `ollama run --num-ctx`). Con 8 GiB de
  # VRAM usar num_ctx <= 8192: el KV cache de 131k no cabe y la maquina se traba.
  services.ollama.environmentVariables = {
    OLLAMA_CONTEXT_LENGTH = "16384";
    # Truco 1: flash attention -> menos VRAM para el KV cache y atencion mas rapida.
    # Truco 2: KV cache en q8_0 (mitad de memoria que f16) -> mas capas caben en la
    # GPU. Ambos suman ~5-15% de t/s; el 2x real viene de MoE a3b + num_ctx 8192.
    OLLAMA_FLASH_ATTENTION = "1";
    OLLAMA_KV_CACHE_TYPE = "q8_0";
    # Reserva VRAM para el escritorio: sin esto ollama se come los 8GiB completos
    # y Hyprland renderiza desde GTT (ram del sistema) -> la UI se arrastra.
    # OLLAMA_GPU_OVERHEAD va en BYTES (envconfig/config.go): el valor previo de
    # 1024 era 1KiB, un no-op -> por eso el desktop seguía congelándose.
    # Medido en la máquina real: escritorio en reposo = 0.9 GiB de VRAM; con
    # overhead 1GiB ollama llega a 7.8 GiB totales -> headroom real 0.2 GiB ->
    # Hyprland cae a GTT -> micro-congelamientos. El overhead debe cubrir el uso
    # del escritorio (0.9 GiB) + margen: 2GiB = ~1.1 GiB libres de verdad.
    # 2147483648 = 2GiB. Coste: ~8 t/s (27 vs 35 medidos) - aceptado.
    OLLAMA_GPU_OVERHEAD = "2147483648";
    # Micro-congelamientos parte 2: saturación de CPU. Con 23 GB de modelo y
    # 8 GiB de VRAM, ollama corre ~73% del cómputo en CPU (medido: 73%/27%
    # CPU/GPU) y los 16 hilos se saturan -> Hyprland no tiene CPU. Limitar a 12
    # hilos deja 4 garantizados al escritorio; coste ~10% de t/s.
    # La combinación 2GiB overhead + 12 hilos es la que elimina AMBAS causas.
    OLLAMA_CPU_THREADS = "12";
  };

  environment.etc."xdg/menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
      <Layout>
        <Merge type="all"/>
      </Layout>
    </Menu>
  '';

  # El system-path de NixOS (buildEnv) solo enlaza los share/ cubiertos por
  # environment.pathsToLink; sin esto share/kicad-spice-library NO aparece en
  # /run/current-system/sw/share (igual que share/kicad del propio KiCad, que
  # resuelve sus librerias por rutas compiladas). Este es el unico "share de
  # datos" que necesitamos visible a ruta estable en todos los hosts.
  environment.pathsToLink = [ "/share/kicad-spice-library" ];

  environment.systemPackages = with pkgs; [
      # Browsers
    tor-browser
    brave-origin

    # Office & Productivity
    # libreoffice-stable: upstream cambio su esquema de versiones y nixpkgs
    # deprecó el attr viejo (libreoffice-fresh emite evaluation warning).
    libreoffice-stable
    keepassxc

    # LaTeX completo (scheme-full: todas las colecciones, fuentes y utilidades)
    (texlive.withPackages (ps: [ ps.scheme-full ]))

    # Graphics & Design
    blender
    gimp
    krita
    inkscape

    # Engineering & Simulation
    kicad
    # ngspice CLI: el mismo motor SPICE que KiCad embebe, pero como binario
    # standalone para correr netlists .cir por terminal (practicas de
    # universidad: scripts de simulación, análisis .tran/.ac/.dc).
    ngspice
    # Librería comunitaria ~50k modelos SPICE (overlay spiceLibraryOverlay):
    # datos en share/kicad-spice-library + `spice-find <modelo>` para buscar.
    # En KiCad: `.include /run/current-system/sw/share/kicad-spice-library/
    # Models/...` como directiva SPICE del esquemático (o extraer al proyecto
    # con Scripts/extractModels.pl; el GUI form_spice.py tambien extrae).
    kicad-spice-library
    freecad
    openrocket
    openmotor
    qucs-s
    simulide
    logisimDark

    # HDL / FPGA simulation (universidad, arquitectura de computadoras):
    # alternativa 100% Linux al Active-HDL (Windows-only) del profe. Cubre
    # ambos lenguajes por si la clase es VHDL o Verilog.
    #   ghdl     -> simulador VHDL (el estandar libre en Linux)
    #   iverilog -> simulador Verilog
    #   verilator-> compilador Verilog/SV rapidisimo (industria real)
    #   gtkwave  -> visor de formas de onda (VCD/FST) = la "GUI" que falta
    # Flujo tipico VHDL: ghdl -a foo.vhd && ghdl -e top && ghdl -r top --vcd=x.vcd
    # luego `gtkwave x.vcd`. Los .vcd producidos son estandar, el profe los abre
    # en cualquier visor.
    ghdl
    iverilog
    verilator
    gtkwave
    vhdlnew
    vhdlrun

    # Telecomunicaciones (universidad)
    # 4nec2 es Windows-only; xnec2c es su equivalente libre en Linux (mismo
    # motor NEC2, GUI con diagramas de radiacion y Smith). openems existe en
    # nixpkgs pero es FDTD por consola (sin GUI): exagerado para el curso.
    # geogebra6 ELIMINADO (2026-08-16): upstream borró la URL del tarball
    # 6-0-794 (404) y el humano no lo usa — YAGNI. Si vuelve a necesitarse,
    # verificar version actual en download.geogebra.org/installers/6.0/.
    xnec2c
    wireshark
    # GNU Radio + GRC (gnuradio-companion): radio definida por software/SDR
    gnuradio

    # Audio & Video Production
    audacity
    mixxx
    shotcut
    obs-studio
    vlc
    # ffmpeg-full: incluye libplacebo (tonemap HDR por GPU vía Vulkan) y
    # libzimg, necesarios para convertir clips HDR10+ a SDR sin lavarlos.
    ffmpeg-full

    # AI & Development
    # octaveFull trae la GUI Qt; el octave base viene sin GUI (solo CLI).
    octaveFull
    ollama
    # whisper-cpp con GPU ya va DENTRO del wrapper de shotcut (mismo bin/).
    # Aquí NO se instala suelto para no duplicar el binario en el system path:
    # el wrapper de shotcut ya expone whisper-cli adyacente a shotcut, que es
    # donde Shotcut lo busca. `subtitular` (shell.nix) usa el mismo whisper-cli
    # del PATH, y el wrapper lo provee vía systemPackages.

      # Virtualization
    virt-manager

    # Networking & VPN
    proton-vpn

    # Android
    android-tools

    # Embedded & IoT (arduino, esp32, stm32)
    arduino-cli
    esptool
    stm32flash
    openocd

    # Raspberry Pi
    rpiboot
    raspberrypi-eeprom
    picocom

    # Dev toolchains
    rustup
    pnpm

    # Fun
    cbonsai

    # Audio Routing
    qpwgraph

    # Utility
    openssl
    qalculate-gtk
    usbutils
    scrcpy
    syncthing
    smartmontools
    cmatrix
    nvtopPackages.amd
    amdgpu_top
    popsicle
  # Dolphin standalone (sin Plasma) necesita el stack KIO completo para
  # desbloquear/montar discos (kded, kio-extras: prompts de passphrase, kioslaves).
  # plasma-workspace aporta el modulo kded "soliduiserver" que muestra el dialogo
  # de passphrase al hacer click en un disco LUKS (Solid depende de el: llama a
  # org.kde.kded6 /modules/soliduiserver; sin el, el click se cuelga).
  ] ++ (with pkgs.kdePackages; [ dolphin kdeconnect-kde kio kio-extras kio-fuse kded plasma-workspace ark okular ffmpegthumbs partitionmanager filelight ]);
}
