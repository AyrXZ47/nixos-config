{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableAutosuggestions = true;
    syntaxHighlighting.enable = true;
    autoclose = true;

    oh-my-zsh = {
      enable = true;
      theme = "powerlevel10k/powerlevel10k";
      plugins = [
        "git"
        "sudo"
      ];
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      }
    ];

    initExtraFirst = ''
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi
    '';

    initExtra = ''
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

      bindkey "^[[1;5C" forward-word
      bindkey "^[[1;5D" backward-word
      bindkey "^H" backward-delete-word
      bindkey "^[[3;5~" delete-word

      [ -f /usr/share/fzf/shell/completion.zsh ] && source /usr/share/fzf/shell/completion.zsh
      [ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh

      fastfetch
    '';

    localVariables = {
      ZSH = "$HOME/.oh-my-zsh";
    };
  };

  home.sessionVariables = {
    OLLAMA_API_BASE = "http://127.0.0.1:11434";
    EDITOR = "nvim";
    COLORTERM = "truecolor";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/.opencode/bin"
    "$HOME/.local/share/pnpm/bin"
  ];

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  home.shellAliases = {
    ls = "ls --color=auto";
    ll = "ls -lah";
    la = "ls -A";
    l = "ls -CF";
    grep = "grep --color=auto";
    nv = "nvim";
    cat = "bat";
    du = "dust";
    ps = "procs";
    top = "btop";
    tree = "eza --tree";
  };

  programs.bat.enable = true;
  programs.direnv.enable = true;
  programs.eza.enable = true;
}
