{ pkgs, opencodeTarball, ... }:

{
  # No tocar sin leer el changelog de nix-on-droid antes de subir de version.
  system.stateVersion = "24.05";

  # El tarball llega aqui via extraSpecialArgs del flake (module system top);
  # home-manager.config se evalua como submódulo y NO hereda esos args — se
  # re-expone con la opcion home-manager.extraSpecialArgs (ver abajo).
  home-manager.extraSpecialArgs = { inherit opencodeTarball; };

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
    # btop no (verificado bajo proot): 1) pide un terminal real — proot no
    # expone /dev/tty usable y muere con 'No tty detected!' antes de hacer nada;
    # 2) proot falsifica /proc/stat con un stub minimo (solo 'btime 0', el
    # changelog de nix-on-droid documenta: "allows unpatched htop to work") y el
    # Cpu::collect() de btop tampoco lo parsearia. htop es el monitoreo que el
    # stub y la falta de tty soportan.
    htop
    # ping bajo proot: iputils funciona solo si el kernel deja abrir raw
    # sockets (SELinux del fabricante manda); si falla con 'Operation not
    # permitted' no hay arreglo sin root. ponytail: ceiling del entorno.
    iputils
    curl
    # Coreutils de terminal que el env default de nix-on-droid NO trae (el
    # template solo mete bashInteractive, coreutils, cacert, less y nix): sin
    # esto no hay grep, sed, tar, zip ni find en el celular.
    gnugrep
    gnused
    gnutar
    gzip
    bzip2
    xz
    zip
    findutils
    diffutils
    procps
    killall
    # patchelf: solo lo usa la activacion de opencode para re-apuntar el
    # interpreter ELF al loader de glibc de nix (el binario standalone pide
    # /lib/ld-linux-aarch64.so.1, que no existe en nix-on-droid).
    patchelf
    # Herramientas de desarrollo y terminal completas.
    # OJO: opencode NO va aqui — se instala por activacion de home-manager
    # (ver abajo): el output nix del binario standalone no viene de la cache
    # binaria, el store del celular lo pierde y el profile queda con symlink
    # muerto ('command not found' sin error). La activacion lo extrae del
    # tarball del flake source a ~/.opencode/bin en cada switch.
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
  ];

  # Reutiliza los módulos home del repo (shell con powerlevel10k, nvim con
  # plugins, git). Requiere el home-manager nuevo (ver flake.nix).
  # No se importan wezterm (Android usa la terminal de Termux), mpd ni firefox
  # (dependen de systemd).
  # fastfetch tampoco: el config del pc usa logo PNG (protocolo kitty) y lineas
  # de 70+ chars que en la terminal angosta del celular envuelven y se pisan.
  # Aqui fastfetch corre con su config por defecto (logo ascii, ajusta ancho).
  home-manager.config = { config, pkgs, lib, opencodeTarball, ... }: {
    home.stateVersion = "24.05";
    imports = [
      ../modules/apps/shell.nix
      ../modules/apps/git.nix
      ../modules/apps/neovim.nix
      ../modules/apps/fastfetch.nix
      ../modules/apps/opencode.nix
      ../modules/apps/serena.nix
    ];

    # fastfetch con la MISMA config que la pc (separador, titulo, modulos),
    # pero con logo ascii de nixos: el PNG va por protocolo kitty, que la app
    # de Termux no soporta, y por defecto fastfetch detecta Android/linux y
    # muestra un Tux. La lista de modulos de la pc imprime menos cosas que el
    # default de fastfetch (que añade disk/battery/localip...) -> mas rapido
    # bajo proot.
    modules.apps.fastfetch.asciiLogo = true;

    # El modulo git compartido (modules/apps/git.nix) pone
    # credential.helper = libsecret (el keyring de GNOME de los hosts de
    # escritorio); en el celular no existe libsecret y git se cae a pedir
    # usuario/contraseña en remotes HTTPS. Aqui se usa SSH (remote
    # git@github.com, llave en el repo) y para HTTPS el helper de gh (ya
    # instalado y autenticado). El tipo de settings NO admite null en este
    # home-manager, asi que se sobrescribe con la cadena del helper.
    programs.git.settings.credential.helper = lib.mkForce "!gh auth git-credential";

    # PATH para el binario que extrae la activacion de abajo. No va en el
    # sessionPath de shell.nix (compartido con los hosts de escritorio): alla
    # el binario viene de pkgs.opencode y la entrada era una reliquia que
    # dejaria a un self-update sombrear el paquete nix (e30559b la quito del
    # PC con razon). Aqui no hay pkgs.opencode: sin esta entrada, zsh dice
    # 'command not found' aunque el binario corra bien por ruta completa.
    home.sessionPath = [ "$HOME/.opencode/bin" ];

    # opencode autocurable: el tarball viaja en el flake source (re-copiado
    # fresco en cada switch, imposible que falte) y esta activacion lo extrae
    # a ~/.opencode/bin — en el PATH via home.sessionPath (ver arriba). No hay
    # store path nix que corromper ni symlink muerto posible: cada switch lo
    # reinstala. OJO: sobreescribe el binario si opencode se auto-actualizo
    # (version pinneada declarativa — feature, no bug).
    home.activation.installOpencode = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      mkdir -p "$HOME/.opencode/bin"
      # La activacion corre con PATH minimo: tar no encuentra gzip (Cannot
      # exec) y su propio gzip esta fuera del profile aun. Rutas absolutas y
      # pipe explicito, sin -z.
      ${pkgs.gzip}/bin/gzip -dc "${opencodeTarball}" | ${pkgs.gnutar}/bin/tar -xf - -C "$HOME/.opencode/bin"
      # El binario standalone (bun --single) pide /lib/ld-linux-aarch64.so.1,
      # que NO existe en nix-on-droid -> 'no such file or directory' al
      # ejecutar aunque el archivo exista. patchelf re-apunta el interpreter
      # al loader de glibc del store (el mismo que corre todo lo demas).
      ${pkgs.patchelf}/bin/patchelf --set-interpreter "${pkgs.glibc}/lib/ld-linux-aarch64.so.1" "$HOME/.opencode/bin/opencode"
      chmod +x "$HOME/.opencode/bin/opencode"
    '';

    # Máximo 3 generaciones SIEMPRE (por conteo, no por edad), igual que
    # trim-generations de modules/core/nix-optimization.nix en los hosts de
    # escritorio: allí lo fuerza un timer systemd diario; aquí no hay systemd,
    # así que se poda en CADA switch y después se lanza el GC. `|| true` por si
    # algún perfil todavía no existe (primer switch).
    # OJO proot: nix escanea /proc/*/fd buscando GC roots y proot responde
    # read_symlink: EPERM — es no-fatal, lo imprime como "error:" y ensucia el
    # final de cada rebuild. El filtro quita SOLO esa línea (Operation not
    # permitted), no otros errores reales de nix.
    home.activation.trimGenerations = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/nix-on-droid --delete-generations +3 2>&1 | ${pkgs.gnugrep}/bin/grep -v "Operation not permitted" || true
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/per-user/nix-on-droid/profile --delete-generations +3 2>&1 | ${pkgs.gnugrep}/bin/grep -v "Operation not permitted" || true
      ${pkgs.nix}/bin/nix-env -p "$HOME/.local/state/nix/profiles/home-manager" --delete-generations +3 2>&1 | ${pkgs.gnugrep}/bin/grep -v "Operation not permitted" || true
      ${pkgs.nix}/bin/nix-collect-garbage 2>&1 | ${pkgs.gnugrep}/bin/grep -v "Operation not permitted" || true
      # (El store ya queda liberado: al podar generaciones, sus closures pasan a
      # ser basura y el GC de la línea anterior la recoge.)
    '';
  };



  # Identidad git sincronizada con modules/apps/git.nix del repo.
  environment.etc."gitconfig".text = ''
    [user]
      name = Yovick RZ
      email = 66042604+AyrXZ47@users.noreply.github.com
    [init]
      defaultBranch = main
    [safe]
      directory = *
  '';

  # Terminal con el esquema Cyberdyne, el mismo de wezterm en la pc
  # (config.color_scheme = "Cyberdyne" en modules/apps/wezterm.nix): asi el
  # celular es reflejo exacto de la pc. OJO: cambiar colores aqui (declarativo);
  # termux-style no funciona porque colors.properties es un symlink de solo
  # lectura al store de nix y cualquier edicion se pisa en el proximo switch.
  terminal.colors = {
    background = "#151144";
    foreground = "#00ff92";
    cursor = "#00ff9c";
    color0 = "#080808";
    color1 = "#ff8373";
    color2 = "#00c172";
    color3 = "#d2a700";
    color4 = "#0071cf";
    color5 = "#ff90fd";
    color6 = "#6bffdd";
    color7 = "#f1f1f1";
    color8 = "#2e2e2e";
    color9 = "#ffc4be";
    color10 = "#d6fcba";
    color11 = "#fffed5";
    color12 = "#c2e3ff";
    color13 = "#ffb2fe";
    color14 = "#e6e7fe";
    color15 = "#ffffff";
  };

  # JetBrainsMono Nerd Font (la misma de wezterm en la pc): la app de Termux lee
  # ~/.termux/font.ttf igual que termux. OJO: debe ir aqui (terminal.font) y NO
  # via home.file: la app corre FUERA del proot y un symlink a /nix/store apunta
  # a una ruta que solo existe dentro del proot -> cae a su fuente default y los
  # iconos de p10k salen como cuadros/simbolos raros. Este modulo reescribe el
  # prefijo /nix a la ruta real del dispositivo (/data/data/.../usr/nix/store/...).
  # Reiniciar la app de Termux (cerrar todas las sesiones y reabrirla) para que
  # cargue la fuente.
  terminal.font = "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf";

  # Integracion Android: symlinks a storage, abrir archivos/urls, wake-lock.
  android-integration.termux-setup-storage.enable = true;
  android-integration.termux-open.enable = true;
  android-integration.termux-open-url.enable = true;
  android-integration.termux-wake-lock.enable = true;
}
