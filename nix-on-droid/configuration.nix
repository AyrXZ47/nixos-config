{ pkgs, ... }:

{
  # No tocar sin leer el changelog de nix-on-droid antes de subir de version.
  system.stateVersion = "24.05";

  # OJO: el default de nix-on-droid es bash. Sin esto la terminal abre en bash:
  # sin p10k, sin aliases (tree/dev/ll), sin fastfetch al abrir, sin fzf. El
  # modulo home de programs.zsh SOLO genera los rc; el shell de login lo fija
  # esto (en NixOS lo haria users.users.<name>.shell, aqui no existe).
  user.shell = "${pkgs.zsh}/bin/zsh";

  # Zona horaria, misma que el resto de los hosts.
  time.timeZone = "America/Mexico_City";

  # Esenciales de terminal movil: git, ssh, editor, busqueda, monitoreo.
  # OJO: git, neovim y fzf NO van aqui: los instalan los módulos home del repo
  # (programs.git, programs.neovim, programs.fzf) y nix-on-droid junta TODO en
  # un solo buildEnv -> "two given paths contain a conflicting subpath".
  environment.packages = with pkgs; [
    openssh
    ripgrep
    fd
    btop
    curl
    # Herramientas de desarrollo y terminal completas.
    opencode
    gh
    jq
    nodejs
    python3
    rustup
    tmux
    unzip
    wget
    sqlite
    openssl
    gnupg
    cmatrix
    # LaTeX para escribir documentos desde el celular (pdflatex, amsmath, ...).
    (pkgs.texlive.withPackages (ps: [ ps.scheme-medium ]))
  ];

  # Reutiliza los módulos home del repo (shell con powerlevel10k, nvim con
  # plugins, git). Requiere el home-manager nuevo (ver flake.nix).
  # No se importan wezterm (Android usa la terminal de Termux), mpd ni firefox
  # (dependen de systemd).
  # fastfetch tampoco: el config del pc usa logo PNG (protocolo kitty) y lineas
  # de 70+ chars que en la terminal angosta del celular envuelven y se pisan.
  # Aqui fastfetch corre con su config por defecto (logo ascii, ajusta ancho).
  home-manager.config = { config, pkgs, lib, ... }: {
    home.stateVersion = "24.05";
    imports = [
      ../modules/apps/shell.nix
      ../modules/apps/git.nix
      ../modules/apps/neovim.nix
    ];
  };



  # Identidad git sincronizada con modules/apps/git.nix del repo.
  environment.etc."gitconfig".text = ''
    [user]
      name = Yovick R. Z.
      email = yovickrz@gmail.com
    [init]
      defaultBranch = main
    [safe]
      directory = *
  '';

  # Terminal con el palette cyberpunk de wayle (styling.palette en hyprland.nix).
  terminal.colors = {
    background = "#0a0a12";
    foreground = "#d4d4f0";
    cursor = "#ff0066";
    color0 = "#141428";
    color1 = "#ff0040";
    color2 = "#00ff88";
    color3 = "#ffcc00";
    color4 = "#00aaff";
    color5 = "#ff0066";
    color6 = "#8888aa";
    color7 = "#d4d4f0";
    color8 = "#0a0a12";
    color9 = "#ff0040";
    color10 = "#00ff88";
    color11 = "#ffcc00";
    color12 = "#00aaff";
    color13 = "#ff0066";
    color14 = "#8888aa";
    color15 = "#d4d4f0";
  };

  # Integracion Android: symlinks a storage, abrir archivos/urls, wake-lock.
  android-integration.termux-setup-storage.enable = true;
  android-integration.termux-open.enable = true;
  android-integration.termux-open-url.enable = true;
  android-integration.termux-wake-lock.enable = true;
}
