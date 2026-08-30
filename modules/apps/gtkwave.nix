# GTKWave: el visor de ondas del flujo ghdl+gtkwave. De fabrica abre la trama
# alejada (todo se ve como rallitas ilegibles) y con fuentes diminutas; este
# rc (leido de ~/.gtkwaverc al arrancar) fija zoom-fit al cargar, ventana
# grande y fuente grande, para poder LEER los diagramas de tiempo de clase.
# ponytail: GTKWave solo lee este rc (no lo reescribe salvo "Write RC"
# manual), si nixpkgs lo empaqueta con defaults sanos, borrar.
{ config, pkgs, lib, ... }:

{
  home.file.".gtkwaverc".text = ''
    do_initial_zoom_fit 1
    initial_window_x 1600
    initial_window_y 900
    use_big_fonts 1
    wave_scrolling 1
  '';
}