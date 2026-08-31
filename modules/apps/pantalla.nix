{ pkgs, lib, ... }:

{
  # Registro del desgaste del panel MSI G2412 (barra negra inferior + líneas
  # verdes que crecen): `registro-pantalla` captura la pantalla, mide la zona
  # muerta desde abajo y la agrega a ~/Pictures/pantalla/registro.csv con la
  # captura PNG como evidencia visual del día.
  home.packages = with pkgs; [
    grim # capturas wayland; también sirve para leer pantalla: grim - | tesseract - stdout
    tesseract
    (pkgs.writeShellScriptBin "registro-pantalla" ''
      set -euo pipefail
      dir="$HOME/Pictures/pantalla"
      mkdir -p "$dir"
      tmp=$(mktemp /tmp/registro-XXXXXX.ppm)
      trap 'rm -f "$tmp"' EXIT
      export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.grim pkgs.ffmpeg pkgs.python3 ]}:$PATH
      grim -t ppm "$tmp"
      ts=$(date +%F_%H%M)
      ffmpeg -loglevel error -y -i "$tmp" "$dir/captura-$ts.png" </dev/null
      stats="$(${lib.getExe pkgs.python3} ${../../assets/pantalla/registro.py} "$tmp")"
      [ -s "$dir/registro.csv" ] || echo "fecha;barra_px;barra_pct;oscura_px;oscura_pct" > "$dir/registro.csv"
      echo "$ts;$stats" >> "$dir/registro.csv"
      echo "$ts | barra/oscura (px;%;px;%): $stats"
      echo "captura: $dir/captura-$ts.png"
    '')
  ];
}
