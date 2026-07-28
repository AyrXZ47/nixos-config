{ config, pkgs, lib, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    withRuby = true;

    extraLuaConfig = ''
      local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
      if not (vim.uv or vim.loop).fs_stat(lazypath) then
        local lazyrepo = "https://github.com/folke/lazy.nvim.git"
        local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
        if vim.v.shell_error ~= 0 then
          vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
          }, true, {})
          vim.fn.getchar()
          os.exit(1)
        end
      end
      vim.opt.rtp:prepend(lazypath)

      require("lazy").setup({
        spec = {
          { "LazyVim/LazyVim", import = "lazyvim.plugins", opts = { colorscheme = "cyberpunk-neon" } },
          { import = "plugins" },
        },
        defaults = {
          lazy = false,
          version = false,
        },
        install = { colorscheme = { "tokyonight", "habamax" } },
        checker = {
          enabled = true,
          notify = false,
        },
        performance = {
          rtp = {
            disabled_plugins = {
              "gzip",
              "tarPlugin",
              "tohtml",
              "tutor",
              "zipPlugin",
            },
          },
        },
      })
    '';

    plugins = with pkgs.vimPlugins; [
      # Theme
      cyberpunk-neon-nvim

      # Utility
      plenary-nvim

      # Rainbow delimiters
      rainbow-delimiters-nvim

      # Treesitter context
      nvim-treesitter-context

      # LSP Lines
      lsp-lines-nvim

      # Obsidian
      obsidian-nvim

      # Ollama
      ollama-nvim

      # Markdown rendering
      render-markdown-nvim

      # Image clipboard
      img-clip-nvim

      # Smear cursor
      smear-cursor-nvim
    ];
  };

  home.packages = with pkgs; [
    lua-language-server
    stylua
    nodePackages.typescript-language-server
    nodePackages.pyright
  ];
}
