{ ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 14.0;
    };
    # Tema vendorizado de johndrews/kitty-cyberpunk (MIT): se copia al repo
    # como asset para no depender de GitHub en runtime. Trae la paleta completa
    # (colores, cursor, selección), por eso ya no se duplican en `settings`.
    extraConfig = "include ${../../assets/kitty-cyberpunk.conf}";
    # La shell integration de kitty engancha zle-line-init/zle-line-finish
    # (cambio de forma del cursor) y eso pisa el widget con el que p10k colapsa
    # el prompt anterior: kitty mismo lo llama un "minefield" y recomienda
    # `no-cursor` justamente para no tocar widgets de zle. Sin el hook, p10k
    # vuelve a mostrar el transient prompt (el `❯`/candado en el historial).
    shellIntegration.mode = "no-cursor";
    settings = {
      # Vidrio (0.66 como el resto de Caelestia; el blur lo da Hyprland)
      background_opacity = "0.66";
      dynamic_background_opacity = "yes";
      # Smear cursor (nativo de kitty)
      cursor_trail = "1";
      cursor_trail_decay = "0.1 0.3";
      cursor_trail_start_threshold = "1";
      # Ventana
      window_padding_width = "10";
      confirm_os_window_close = "0";
      enable_audio_bell = "no";
      # Scroll del trackpad: en Wayland es un dispositivo de alta precisión, así
      # que manda `touch_scroll_multiplier` y no `wheel_scroll_multiplier`. El
      # default 1.0 se siente lento en outputs largos; 3.0 conserva la suavidad
      # (pixel_scroll sigue en su default `yes`) con más avance por gesto.
      touch_scroll_multiplier = "3.0";
      # Control remoto disponible para uso manual (lanzar ventanas/splits con
      # el CLI de kitty). hyprdev ya no usa `kitty @`.
      allow_remote_control = "yes";
      # Emoji a color: fontconfig resuelve símbolos como 🔒 (U+1F512) a
      # Noto Sans Symbols 2 (monocromo) antes que a Noto Color Emoji; el
      # symbol_map fuerza esos rangos a la fuente de color. Solo bloques emoji
      # de verdad: meter U+2600–U+27BF o U+2190–U+21FF (que también traen ❯ ❮ ← →)
      # manda esos glifos a Noto Color Emoji, que NO los tiene, y kitty los deja
      # en blanco — adiós prompt ❯ y flechas. U+2B00–U+2BFF cubre la estrella ⭐.
      symbol_map = "U+1F300-U+1FAFF,U+2B00-U+2BFF Noto Color Emoji";
      # Splits nativos de kitty
      enabled_layouts = "splits";
    };
    keybindings = {
      "ctrl+page_up" = "previous_window";
      "ctrl+page_down" = "next_window";
      "ctrl+shift+alt+percent" = "launch --location=vsplit --cwd=current";
      "ctrl+shift+alt+quotedbl" = "launch --location=hsplit --cwd=current";
    };
  };
}
