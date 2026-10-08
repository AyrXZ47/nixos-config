# Siembra el editor externo de Vivado (kitty+nvim) en sus preferencias, para no
# tener que pasar por Tools > Settings > Text Editor > Custom Editor en cada host.
#
# Vivado guarda el ajuste en ~/.Xilinx/Vivado/<version>/newvivado.xml como dos
# claves escalares: CODE_EDITOR="Custom Editor..." y CODE_EDITOR_ARGUMENTS con el
# comando. Verificado desensamblando planAhead.jar (ui/j/c/d y ui/frmwork/aK):
# el string centinela es literal y el XML usa <KEY value="..."/>.
#
# ponytail: techo conocido — se parchea el XML a mano; si AMD cambia el nombre
# del archivo o el esquema de claves (p.ej. deja de ser "Custom Editor..." o el
# archivo pasa a ser vivado.xml sin _UPGRADED), habrá que actualizar estas dos
# constantes. El nombre del directorio es version-agnóstico (glob sobre
# ~/opt/Xilinx/*/Vivado), así que un bump de versión no rompe esto.
{ pkgs }:
pkgs.writeShellApplication {
  name = "vivado-nvim-seed";
  runtimeInputs = with pkgs; [ coreutils gnused gnugrep ];
  text = ''
    prefix="$HOME/.Xilinx/Vivado"

    seed() {
      file="$1"
      if [ -s "$file" ] && grep -q '<CODE_EDITOR ' "$file"; then
        return 0
      fi
      mkdir -p "$(dirname "$file")"
      if [ -s "$file" ]; then
        sed -i 's#</preferences>#  <CODE_EDITOR value="Custom Editor..."/>\n  <CODE_EDITOR_ARGUMENTS value="vivado-nvim +[line number] [file name]"/>\n</preferences>#' "$file"
      else
        {
          printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
          printf '%s\n' '<preferences VERSION="10">'
          printf '%s\n' '  <CODE_EDITOR value="Custom Editor..."/>'
          printf '%s\n' '  <CODE_EDITOR_ARGUMENTS value="vivado-nvim +[line number] [file name]"/>'
          printf '%s\n' '</preferences>'
        } > "$file"
      fi
    }

    # Versiones con instalación en ~/opt/Xilinx pero todavía sin preferencias.
    for install in "$HOME"/opt/Xilinx/*/Vivado; do
      if [ -d "$install" ]; then
        seed "$prefix/$(basename "$(dirname "$install")")/newvivado.xml"
      fi
    done

    # Cualquier archivo de preferencias que ya exista.
    for file in "$prefix"/*/newvivado.xml; do
      if [ -e "$file" ]; then
        seed "$file"
      fi
    done
  '';
}
