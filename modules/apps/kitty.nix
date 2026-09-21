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
      # Control remoto disponible para uso manual (lanzar ventanas/splits con
      # el CLI de kitty). hyprdev ya no lo usa.
      allow_remote_control = "yes";
      shell_integration = "enabled";
      # Emoji a color: fontconfig resuelve símbolos como 🔒 (U+1F512) a
      # Noto Sans Symbols 2 (monocromo) antes que a Noto Color Emoji; el
      # symbol_map fuerza esos rangos a la fuente de color.
      symbol_map = "U+1F300-U+1FAFF,U+2600-U+27BF,U+2190-U+21FF Noto Color Emoji";
      # Wezterm-like: splits nativos de kitty
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
