{lib, pkgs, ... }:

{
  # 1. Dependencias Base y Herramientas CLI de tu repo linux-tweaks
  home.packages = with pkgs; [
    # Terminal & Fetch
    wezterm
    fastfetch
    
    # CLI Utilidades
    ripgrep
    fd
    unzip
    fzf
    
    # Herramientas IA Locales y CLI
    aider-chat
    # Para OpenCode y Headroom podemos requerir paquetes de python/nodejs
    python313
    uv
    nodejs_22
    nodePackages.pnpm
    
    # Fuentes (JetBrains Mono Nerd Font para íconos cyberpunk)
    nerd-fonts.jetbrains-mono
  ];

  # 2. Configuración declarativa de Zsh (Reemplaza setup manual)
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "fzf" ];
    };

    # Inicialización de Powerlevel10k
    initExtra = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
    '';
  };

  # Paquete de Powerlevel10k necesario para Zsh
  home.packages = [ pkgs.zsh-powerlevel10k ];

  # 3. Fix para PipeWire: Bloquear control de volumen de Chrome
  xdg.configFile."pipewire/pipewire-pulse.conf.d/10-block-chrome-volume.conf".text = ''
    pulse.rules = [
      {
        matches = [ { application.process.binary = "chrome" } ];
        actions = { quirks = [ "block-source-volume" ] };
      }
      {
        matches = [ { application.name = "~(Chromium|Google Chrome).*" } ];
        actions = { quirks = [ "block-source-volume" ] };
      }
    ]
  '';

  # 4. Servicio Systemd en el espacio de usuario para Headroom Proxy
  systemd.user.services.headroom-proxy = {
    Unit = {
      Description = "Headroom AI Context Optimization Proxy";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      # Ajusta el comando exacto al ejecutable gestionado por uv/headroom
      ExecStart = "${pkgs.uv}/bin/uv tool run headroom wrap --serve";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
