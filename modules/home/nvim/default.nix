{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    
    # Herramientas extra requeridas por plugins de LazyVim
    extraPackages = with pkgs; [
      lua-language-server
      stylua
      gcc
      tree-sitter
    ];
  };

  # TRUCO DE ARQUITECTO: En lugar de symlinks individuales, enlazamos todo el directorio 
  # de configuración visual directamente a ~/.config/nvim
  # (Descomenta y ajusta la ruta cuando coloques tus configs de nvim en la carpeta src/ del repo)
  # xdg.configFile."nvim".source = ../../../src/nvim;
}
