{ config, pkgs, lib, ... }:

let
  theme = "cyberneon";

  pluginsDir = {
    ".config/nvim/lua/plugins/theme.lua" = {
      text = ''
        return {
          "followLemmi/cyberneon.nvim",
          name = "cyberneon",
          lazy = false,
          priority = 20000,
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
    ".config/nvim/lua/plugins/img-clip.lua" = {
      text = ''
        return {
          "HakonHarnes/img-clip.nvim",
          event = "VeryLazy",
          opts = {
            default = {
              dir_path = "assets",
              extension = "png",
              prompt_for_file_name = false,
              drag_and_drop = {
                insert_mode = true,
              },
            },
          },
          keys = {
            { "<leader>p", "<cmd>PasteImage<cr>", desc = "Paste image from clipboard" },
          },
        }
      '';
    };
    ".config/nvim/lua/plugins/ollama.lua" = {
      text = ''
        return {
          "nomnivore/ollama.nvim",
          dependencies = { "nvim-lua/plenary.nvim" },
          cmd = { "Ollama", "OllamaModel", "OllamaServe", "OllamaServeStop" },
          opts = {
            model = "qwen3.6:35b-a3b-mtp-q4_K_M",
            serve = {
              on_start = true,
              command = "ollama",
              args = { "serve" },
              stop_command = "pkill",
              stop_args = { "-SIGTERM", "ollama" },
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
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    withRuby = true;

    initLua = ''
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
    '';
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
