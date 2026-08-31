{ config, pkgs, lib, ... }:

{
  programs.wezterm = {
    enable = true;

    extraConfig = ''
      local wezterm = require("wezterm")
      local config = {}

      config.set_environment_variables = { COLORTERM = "truecolor" }
      config.term = "xterm-256color"
      config.color_scheme = "Cyberdyne"
      config.font = wezterm.font("JetBrains Mono Nerd Font")
      config.font_size = 14.0

      config.window_decorations = "NONE"

      config.inactive_pane_hsb = {
        saturation = 1.0,
        brightness = 1.0,
      }

      config.window_background_opacity = 0.4
      config.text_background_opacity = 1.0

      config.use_fancy_tab_bar = false
      config.hide_tab_bar_if_only_one_tab = true

      config.colors = {
        tab_bar = {
          -- Misma transparencia que el fondo de la ventana (window_background_opacity = 0.4):
          -- misma alpha para que la barra se funda con la terminal y "no exista".
          background = "rgba(21, 17, 68, 0.4)",
          active_tab = {
            bg_color = "#00f0ff",
            fg_color = "#0b0814",
            intensity = "Bold",
          },
          inactive_tab = {
            bg_color = "#1a0b1c",
            fg_color = "#ff003c",
          },
          inactive_tab_hover = {
            bg_color = "#ff003c",
            fg_color = "#0b0814",
          },
        },
        cursor_bg = "#ff003c",
        cursor_border = "#ff003c",
        cursor_fg = "#0b0814",
        split = "#ff003c",
      }

      config.window_padding = { left = 6, right = 6, top = 6, bottom = 6 }
      config.initial_cols = 110
      config.initial_rows = 30

      return config
    '';
  };

  home.packages = with pkgs; [ wezterm ];
}
