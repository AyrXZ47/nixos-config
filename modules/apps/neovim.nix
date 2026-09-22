{ config, pkgs, lib, ... }:

let
  theme = "NeoCyberVim";

  pluginsDir = {
    ".config/nvim/lua/plugins/theme.lua" = {
      text = ''
        -- Tema de DonJulve/NeoCyberVim (MIT), vendorizado en assets/nvim/NeoCyberVim
        -- para que no se pierda si upstream borra el repo.
        return {
          {
            dir = "${../../assets/nvim/NeoCyberVim}",
            name = "NeoCyberVim",
            lazy = false,
            priority = 1000,
            opts = { transparent = true },
          },
        }
      '';
    };
    ".config/nvim/lua/plugins/smear-cursor.lua" = {
      text = ''
        return {
          "sphamba/smear-cursor.nvim",
          event = "VeryLazy",
          opts = {},
        }
      '';
    };
    ".config/nvim/lua/plugins/multicursor.lua" = {
      text = ''
        -- jake-stewart/multicursor.nvim: multicursor real para Neovim. Clave
        -- frente a vim-visual-multi: usa "keymap layers", o sea los atajos de
        -- gestión existen SOLO mientras hay multicursor; no pisa teclas
        -- globales de insert/normal (por eso no rompe blink.cmp ni mini.pairs).
        -- Soporta autocompletado y snippets nativos (vim.snippet.expand).
        return {
          "jake-stewart/multicursor.nvim",
          branch = "1.0",
          config = function()
            local mc = require("multicursor-nvim")
            mc.setup()

            local set = vim.keymap.set

            -- Añadir cursor abajo/arriba y en el siguiente match (global).
            set({ "n", "x" }, "<leader>mj", function() mc.lineAddCursor(1) end, { desc = "Multicursor: cursor abajo" })
            set({ "n", "x" }, "<leader>mk", function() mc.lineAddCursor(-1) end, { desc = "Multicursor: cursor arriba" })
            set({ "n", "x" }, "<leader>mn", function() mc.matchAddCursor(1) end, { desc = "Multicursor: siguiente match" })
            set({ "n", "x" }, "<leader>mA", mc.matchAllAddCursors, { desc = "Multicursor: todos los matches" })
            -- Mouse: Ctrl+click añade/quita cursor.
            set("n", "<C-LeftMouse>", mc.handleMouse)

            -- Capa que aplica SOLO con multicursor: rotar, borrar y cerrar.
            mc.addKeymapLayer(function(layerSet)
              layerSet({ "n", "x" }, "<Left>", mc.prevCursor)
              layerSet({ "n", "x" }, "<Right>", mc.nextCursor)
              layerSet({ "n", "x" }, "<leader>md", mc.deleteCursor, { desc = "Multicursor: borrar cursor" })
              layerSet("n", "<Esc>", function()
                if not mc.cursorsEnabled() then
                  mc.enableCursors()
                else
                  mc.clearCursors()
                end
              end)
            end)
          end,
        }
      '';
    };
    ".config/nvim/lua/plugins/obsidian.lua" = {
      text = ''
        return {
          "epwalsh/obsidian.nvim",
          version = "*",
          lazy = true,
          ft = "markdown",
          dependencies = {
            "nvim-lua/plenary.nvim",
          },
          opts = {
            workspaces = {
              {
                name = "personal",
                path = "~/Sync/Notes",
              },
            },
            wiki_link_func = function(opts)
              return require("obsidian.util").wiki_link_id_prefix(opts)
            end,
          },
        }
      '';
    };
    ".config/nvim/lua/plugins/render-markdown.lua" = {
      text = ''
        return {
          "MeanderingProgrammer/render-markdown.nvim",
          dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-mini/mini.nvim",
          },
          opts = {
            heading = {
              icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
              sign = true,
              position = "inline",
            },
            code = {
              sign = true,
              width = "block",
              right_pad = 1,
            },
            bullet = {
              icons = { "●", "○", "◆", "◇" },
            },
            checkbox = {
              unchecked = { icon = "󰄱 " },
              checked = { icon = "󰱒 " },
            },
          },
        }
      '';
    };
    ".config/nvim/lua/plugins/mason.lua" = {
      text = ''
        return {
          "mason-org/mason.nvim",
          opts = function(_, opts)
            opts.ensure_installed = vim.tbl_filter(function(pkg)
              return pkg ~= "tree-sitter-cli"
            end, opts.ensure_installed or {})
          end,
        }
      '';
    };
    ".config/nvim/lua/plugins/gitgraph.lua" = {
      text = ''
        return {
          "isakbm/gitgraph.nvim",
          keys = {
            {
              "<leader>gg",
              function()
                require("gitgraph").draw({}, { all = true, max_count = 5000 })
              end,
              desc = "Git graph",
            },
          },
        }
      '';
    };
    ".config/nvim/lua/plugins/visuals.lua" = {
      text = ''
        return {
          {
            "HiPhish/rainbow-delimiters.nvim",
            event = "BufReadPost",
            config = function()
              local rainbow_delimiters = require("rainbow-delimiters")
              vim.g.rainbow_delimiters = {
                strategy = {
                  [""] = rainbow_delimiters.strategy["global"],
                  vim = rainbow_delimiters.strategy["local"],
                },
                query = {
                  [""] = "rainbow-delimiters",
                  lua = "rainbow-blocks",
                },
                highlight = {
                  "RainbowDelimiterRed",
                  "RainbowDelimiterYellow",
                  "RainbowDelimiterBlue",
                  "RainbowDelimiterOrange",
                  "RainbowDelimiterGreen",
                  "RainbowDelimiterViolet",
                  "RainbowDelimiterCyan",
                },
              }
            end,
          },
          {
            "nvim-treesitter/nvim-treesitter-context",
            event = "BufReadPre",
            opts = {
              enable = true,
              max_lines = 3,
              min_window_height = 0,
              line_numbers = true,
              multiline_threshold = 20,
              trim_scope = "outer",
              mode = "cursor",
              separator = nil,
              zindex = 20,
            },
          },
          {
            "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
            event = "LspAttach",
            config = function()
              require("lsp_lines").setup()
              vim.diagnostic.config({
                virtual_text = false,
                virtual_lines = true,
              })
              vim.keymap.set("", "<leader>ul", function()
                local config = vim.diagnostic.config() or {}
                if config.virtual_text then
                  vim.diagnostic.config({ virtual_text = false, virtual_lines = true })
                else
                  vim.diagnostic.config({ virtual_text = true, virtual_lines = false })
                end
              end, { desc = "Toggle lsp_lines" })
            end,
          },
        }
      '';
    };
  };
in
let
  # HM escribe extraConfig como VIMSCRIPT en init.vim (y el init.lua generado
  # lo sourcea) -> el bootstrap de LazyVim en Lua reventaba en el arranque con
  # "E492: Not an editor command". El bootstrap va en lua, directo a init.lua.
  #
  # Nombre de la opcion segun version de HM: master la renombro a `initLua`
  # (extraLuaConfig queda como alias deprecado -> warning en el build);
  # release-25.11 (el pin de nix-on-droid por el proot/glibc) SOLO tiene
  # extraLuaConfig. `config.programs.neovim ? initLua` detecta cual existe sin
  # forzar valores (los nombres de opcion vienen de las declaraciones, no de
  # las definiciones), asi el rebuild queda limpio en ambos. El bootstrap es
  # autocontenido, así que el orden respecto al init por defecto de HM no
  # importa.
  luaConfig = ''
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

      -- Scroll del trackpad más fino: cada evento del wheel avanza 1 línea en
      -- vez de 3 (default). kitty emite muchos eventos de alta precisión, así
      -- que con 1 línea el gesto se siente suave en lugar de ir a saltos.
      vim.opt.mousescroll = "ver:1,hor:1"

      require("lazy").setup({
        spec = {
          { "LazyVim/LazyVim", import = "lazyvim.plugins" },
          { import = "plugins" },
        },
        defaults = {
          lazy = false,
          version = false,
        },
        install = { colorscheme = { "${theme}", "tokyonight", "habamax" } },
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

      vim.schedule(function()
        vim.cmd.colorscheme("${theme}")
      end)

      vim.keymap.set("n", "<leader>rr", function()
        local search = vim.fn.input("Buscar: ")
        if search == "" then
          return
        end
        local repl = vim.fn.input("Reemplazar por: ")
        vim.cmd(("%%s/%s/%s/gc"):format(vim.fn.escape(search, "/"), vim.fn.escape(repl, "/&")))
      end, { desc = "Buscar y reemplazar en el buffer" })

      vim.keymap.set("n", "<leader>rw", function()
        local repl = vim.fn.input("Reemplazar última búsqueda por: ")
        vim.cmd(("%%s//%s/gc"):format(vim.fn.escape(repl, "/&")))
      end, { desc = "Reemplazar última búsqueda en el buffer" })
    '';
in
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    withRuby = true;

    ${if config.programs.neovim ? initLua then "initLua" else "extraLuaConfig"} = luaConfig;
  };

  home.file = pluginsDir;

  home.packages = with pkgs; [
    gcc
    lua-language-server
    stylua
    typescript-language-server
    pyright
  ];
}
