{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    # 1. Apagamos el defaultEditor automático para tomar el control manual
    defaultEditor = false;
    viAlias = true;
    vimAlias = true;
    
    extraPackages = with pkgs; [
      lua-language-server
      stylua
      gcc
      tree-sitter
    ];
  };

  # 2. TRUCO DE ARQUITECTO: Forzamos la prioridad de Neovim sobre Hydenix
  home.sessionVariables = {
    EDITOR = pkgs.lib.mkForce "nvim";
    VISUAL = pkgs.lib.mkForce "nvim";
  };

  # Cuando pongs tu carpeta de configuración en src/, descomenta esto:
  # xdg.configFile."nvim".source = ../../../src/nvim;
}
