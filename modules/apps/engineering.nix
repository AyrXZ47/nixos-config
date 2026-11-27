# Ingeniería para pc/laptop: KiCad + SPICE, CAD/simulación, HDL/FPGA, GNU Radio,
# herramientas embedded y LaTeX medio. Packet Tracer y Vivado se activan acá
# (no en la VM).
{ config, pkgs, lib, ... }:

let
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
        kind = "signalname" if int(p[2]) == 1 else "pattern"
        lines.append(" {} {}.{}".format(kind, ".".join(scopes), p[4]))
print("\n".join(lines))
PYEOF
    gtkwave "$tb.vcd" "$tb.gtkw" >/dev/null 2>&1 &
  '';
in
{
  # Packet Tracer y Vivado solo en pc/laptop: la VM no los necesita.
  imports = [ ./packettracer.nix ./vivado.nix ];
  modules.apps.packetTracer.enable = true;
  modules.apps.vivado.enable = true;

  # El system-path de NixOS (buildEnv) solo enlaza los share/ cubiertos por
  # environment.pathsToLink; sin esto share/kicad-spice-library NO aparece en
  # /run/current-system/sw/share (igual que share/kicad del propio KiCad, que
  # resuelve sus librerias por rutas compiladas). Este es el unico "share de
  # datos" que necesitamos visible a ruta estable.
  environment.pathsToLink = [ "/share/kicad-spice-library" ];

  environment.systemPackages = with pkgs; [
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
    # GNU Radio + GRC (gnuradio-companion): radio definida por software/SDR.
    # Se inyecta gr-osmosdr (bloque "osmocom Source") via extraPackages: el
    # wrapper lo agrega a GRC_BLOCKS_PATH y al python del env. El bloque
    # "SoapyRTLSDR Source" ya viene de fabrica (gr-soapy + soapyrtlsdr).
    (gnuradio.override { extraPackages = [ gnuradio.pkgs.osmosdr ]; })

    # LaTeX: scheme-medium alcanza para tesis/reportes; scheme-full arrastraba
    # todas las colecciones y fuentes sin uso.
    (texlive.withPackages (ps: [ ps.scheme-medium ]))

    # Embedded & IoT (arduino, esp32, stm32)
    arduino-cli
    esptool
    stm32flash
    openocd

    # Raspberry Pi
    rpiboot
    raspberrypi-eeprom
    picocom
  ];
}
