{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    oh-my-zsh = {
      enable = true;
      theme = "";
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

    initContent = ''
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

      bindkey "^[[1;5C" forward-word
      bindkey "^[[1;5D" backward-word
      bindkey "^H" backward-delete-word
      bindkey "^[[3;5~" delete-word

      [ -f /usr/share/fzf/shell/completion.zsh ] && source /usr/share/fzf/shell/completion.zsh
      [ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh

      # Solo si está instalado: el celular (nix-on-droid) no trae fastfetch.
      command -v fastfetch >/dev/null && fastfetch

      # Parte el kitty ACTUAL en dos: btop (izquierda) y nvtop (45%, derecha).
      # Usa el control remoto de kitty (`kitty @ launch`, exige
      # `allow_remote_control`, lo trae modules/apps/kitty.nix). El panel nuevo
      # va en el layout `splits`: vsplit + bias=45 lo deja a la derecha con el
      # 45% del ancho; btop se queda en la ventana de origen con `exec btop`.
      netrunner() {
        if [[ -z "$KITTY_WINDOW_ID" ]]; then
          echo "Error: Se requiere kitty activo."
          return 1
        fi
        kitty @ goto-layout --match "window_id:$KITTY_WINDOW_ID" splits 2>/dev/null
        kitty @ launch --location=vsplit --bias=45 --next-to "id:$KITTY_WINDOW_ID" zsh -ic nvtop
        exec btop
      }

      # Uso: dev [directorio-repo] — si se pasa, entra al repo antes de partir.
      # Layout (migrado de los panes del dev viejo a los splits de kitty):
      # fila superior nvim (15%, izquierda) + opencode (85%, derecha); fila
      # inferior pipes-rs (15%, izquierda) + terminal libre (85%, derecha).
      # `hsplit --bias=20` crea la fila inferior debajo y `vsplit --bias=85`
      # deja el panel nuevo a la derecha (el bias es el % del panel nuevo).
      dev() {
        if [[ -z "$KITTY_WINDOW_ID" ]]; then
          echo "Error: Se requiere kitty activo."
          return 1
        fi
        local repo="''${1:-}"
        [[ -n "$repo" ]] && { cd "$repo" || return 1; }
        local base="$KITTY_WINDOW_ID" bottom
        kitty @ goto-layout --match "window_id:$base" splits 2>/dev/null
        # Fila inferior completa (20% del alto): pipes-rs queda a la izquierda
        # al partirle la terminal libre a la derecha.
        bottom=$(kitty @ launch --location=hsplit --bias=20 --next-to "id:$base" \
          --cwd "$PWD" zsh -ic pipes-rs)
        # Fila superior: opencode a la derecha (85%); nvim se queda a la izquierda.
        kitty @ launch --location=vsplit --bias=85 --next-to "id:$base" \
          --cwd "$PWD" zsh -ic opencode >/dev/null 2>&1
        [[ -n "$bottom" ]] && kitty @ launch --location=vsplit --bias=85 --next-to "id:$bottom" \
          --cwd "$PWD" zsh >/dev/null 2>&1
        # nvim en la ventana de origen (antes el send-text del dev viejo).
        kitty @ send-text --match "id:$base" 'nvim\r'
        kitty @ focus-window --match "id:$base" 2>/dev/null
      }

      # `hyprdev [directorio-repo]` — la geometría de trabajo en UN panel kitty
      # con 4 splits: nvim arriba-izquierda, opencode arriba-derecha (~75% del
      # ancho × 65% del alto), pipes-rs abajo-izquierda y terminal libre
      # abajo-derecha. Usa el layout `splits` de kitty vía `kitty @ launch
      # --location=vsplit|hsplit --bias=N` (el bias es el % que se lleva el
      # panel nuevo). Si los splits no están disponibles, cae a 4 ventanas
      # kitty independientes con clase hyprdev-<runid>: Hyprland las tilea y
      # caelestia las colapsa en un icono (windowIcons regex `hyprdev.*`),
      # equivalente a las ventanas múltiples del hyprdev anterior. La sesión
      # vive en UNA ventana: cerrarla (SUPER+Q / exit) cierra los 4 paneles,
      # así que se elimina el watcher de cierre en cadena.
      hyprdev() {
        if [[ -z "$KITTY_WINDOW_ID" ]]; then
          echo "Error: Se requiere kitty activo."
          return 1
        fi
        local repo="''${1:-$PWD}"
        local runid="$(date +%s)$RANDOM"
        local base oc pipes

        # --- Intento 1: una sola ventana OS con el layout `splits` ---
        # nvim es la base; --var marca la sesión para limpiarla si hay que caer
        # al fallback. `kitty @ launch` imprime el id de la ventana nueva.
        base=$(kitty @ launch --type=os-window --cwd "$repo" \
          --var "hyprdev=$runid" zsh -ic "nvim; exec zsh" 2>/dev/null)
        if [[ -n "$base" ]] && kitty @ goto-layout --match "window_id:$base" splits 2>/dev/null; then
          # opencode a la derecha con el 75% del ancho de la ventana base.
          oc=$(kitty @ launch --location=vsplit --bias=75 --next-to "id:$base" --cwd "$repo" \
            --var "hyprdev=$runid" zsh -ic opencode 2>/dev/null)
          # pipes-rs debajo de nvim, 35% del alto de la columna izquierda.
          pipes=$(kitty @ launch --location=hsplit --bias=35 --next-to "id:$base" --cwd "$repo" \
            --var "hyprdev=$runid" \
            zsh -ic "pipes-rs -k heavy,dots,sus --rainbow 0 --palette darker -d 50 -r 0" 2>/dev/null)
          if [[ -n "$oc" && -n "$pipes" ]]; then
            # terminal libre debajo de opencode, 35% del alto de la columna derecha.
            kitty @ launch --location=hsplit --bias=35 --next-to "id:$oc" --cwd "$repo" zsh >/dev/null 2>&1
            # Como `dev`, el foco acaba en nvim.
            kitty @ focus-window --match "id:$base" 2>/dev/null
            kitty @ close-window --match "id:$KITTY_WINDOW_ID" >/dev/null 2>&1
            return 0
          fi
        fi

        # --- Fallback: 4 ventanas kitty independientes que Hyprland tilea ---
        # opencode→free→pipes→nvim, misma clase hyprdev-<runid> para el icono
        # único de caelestia y la regla de vidrio (`hyprdev-.*`).
        kitty @ close-window --match "var:hyprdev=$runid" 2>/dev/null
        kitty @ launch --type=os-window --cwd "$repo" --os-window-class "hyprdev-$runid" zsh -ic opencode >/dev/null 2>&1
        kitty @ launch --type=os-window --cwd "$repo" --os-window-class "hyprdev-$runid" zsh >/dev/null 2>&1
        kitty @ launch --type=os-window --cwd "$repo" --os-window-class "hyprdev-$runid" \
          zsh -ic "pipes-rs -k heavy,dots,sus --rainbow 0 --palette darker -d 50 -r 0" >/dev/null 2>&1
        kitty @ launch --type=os-window --cwd "$repo" --os-window-class "hyprdev-$runid" zsh -ic "nvim; exec zsh" >/dev/null 2>&1
        kitty @ close-window --match "id:$KITTY_WINDOW_ID" >/dev/null 2>&1
      }

      SecDesk() {
        adb disconnect
        adb -d shell am kill-all
        adb -d shell settings put system screen_brightness_mode 0
        adb -d shell settings put system screen_brightness 0
        (
          env SDL_VIDEODRIVER=wayland SDL_RENDER_DRIVER=vulkan scrcpy \
            -d --stay-awake --new-display=1920x1080 \
            --video-codec=h265 --video-bit-rate 50M --max-fps 85 \
            --audio-codec=opus --audio-bit-rate 128K --audio-buffer=50 \
            --fullscreen > /dev/null 2>&1
          adb -d shell settings put system screen_brightness_mode 1
        ) &!
      }

      Mirror() {
        adb disconnect
        (
          env SDL_VIDEODRIVER=wayland SDL_RENDER_DRIVER=vulkan scrcpy \
            -d --stay-awake --video-codec=h265 --video-bit-rate 50M --max-fps 85 \
            --fullscreen > /dev/null 2>&1
        ) &!
      }

      SecDesk_WiFi() {
        if [[ -z "$1" ]]; then
          echo "Uso: SecDesk_WiFi <IP_DE_LA_TABLET>"
          return 1
        fi
        adb connect "$1:5555"
        sleep 1
        adb -s "$1:5555" shell am kill-all
        adb -s "$1:5555" shell settings put system screen_brightness_mode 0
        adb -s "$1:5555" shell settings put system screen_brightness 0
        (
          env SDL_VIDEODRIVER=wayland SDL_RENDER_DRIVER=vulkan scrcpy \
            -s "$1:5555" --stay-awake --new-display=1920x1080 \
            --video-codec=h265 --video-bit-rate 16M --max-fps 85 \
            --audio-codec=opus --audio-bit-rate 128K --audio-buffer=50 \
            --fullscreen > /dev/null 2>&1
          adb -s "$1:5555" shell settings put system screen_brightness_mode 1
        ) &!
      }

      Mirror_WiFi() {
        if [[ -z "$1" ]]; then
          echo "Uso: Mirror_WiFi <IP_DE_LA_TABLET>"
          return 1
        fi
        adb connect "$1:5555"
        sleep 1
        (
          env SDL_VIDEODRIVER=wayland SDL_RENDER_DRIVER=vulkan scrcpy \
            -s "$1:5555" --stay-awake --video-codec=h265 --video-bit-rate 16M --max-fps 85 \
            --fullscreen > /dev/null 2>&1
        ) &!
      }

      # YouTube exige PO Token a los clientes web logueados (403 al descargar);
      # tv_downgraded/tv/visionos siguen entregando URLs que funcionan con cookies.
      yt_url() {
        local u="$1"
        [[ -z "$u" ]] && u="$(wl-paste | grep -oE 'https?://(music\.|www\.)?(youtube\.com|youtu\.be)[^[:space:]"]+' | head -1)"
        print -r -- "$u" | tr -d '\\'
      }

      ytsong() {
        local url="$(yt_url "$1")"
        yt-dlp --no-warnings --no-playlist --extract-audio --audio-format opus --audio-quality 0 \
          -f "bestaudio/best" \
          --embed-metadata --embed-thumbnail --js-runtimes node \
          --cookies-from-browser firefox \
          --extractor-args "youtube:player_client=tv_downgraded,tv,visionos" \
          -o "%(uploader)s - %(title)s.%(ext)s" "$url"
      }

      ytlist() {
        local url="$(yt_url "$1")"
        yt-dlp --no-warnings --ignore-errors --extract-audio --audio-format opus --audio-quality 0 \
          -f "bestaudio/best" \
          --embed-metadata --embed-thumbnail --js-runtimes node \
          --cookies-from-browser firefox --download-archive historial_descargas.txt \
          --sleep-requests 1 --sleep-interval 3 --max-sleep-interval 8 \
          --extractor-args "youtube:player_client=tv_downgraded,tv,visionos" \
          -o "%(uploader)s - %(title)s.%(ext)s" "$url"
      }

      estabilizar_clips() {
        mkdir -p listos_para_editar
        for f in *.mp4(N); do
          if [[ ! -f "listos_para_editar/$f" ]]; then
            ffmpeg -i "$f" -threads 0 -c:v libx264 -preset slow -crf 17 \
              -fps_mode cfr -r 30 -c:a copy "listos_para_editar/$f"
          fi
        done
      }

      estabilizar_clips_gpu() {
        mkdir -p listos_para_editar
        for f in *.mp4(N); do
          if [[ ! -f "listos_para_editar/$f" ]]; then
            if ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer \
              -of csv=p=0 "$f" | grep -qE "smpte2084|arib-std-b67"; then
              echo "HDR ($f): tonemap por GPU (libplacebo)"
              ffmpeg -hwaccel vaapi -vaapi_device /dev/dri/renderD128 \
                -init_hw_device vaapi=va:/dev/dri/renderD128 -filter_hw_device va -i "$f" \
                -vf "libplacebo=tonemapping=hable:format=nv12:colorspace=bt709:color_primaries=bt709:color_trc=bt709,hwupload" \
                -c:v h264_vaapi -qp 18 -fps_mode cfr -r 30 -c:a copy "listos_para_editar/$f"
            else
              echo "SDR ($f): conversión directa por GPU"
              ffmpeg -hwaccel vaapi -hwaccel_output_format vaapi \
                -vaapi_device /dev/dri/renderD128 -i "$f" \
                -vf "scale_vaapi=format=nv12" -c:v h264_vaapi -qp 18 \
                -fps_mode cfr -r 30 -c:a copy "listos_para_editar/$f"
            fi
          fi
        done
      }

      subtitular() {
        local FILE="$1"
        if [ -z "$FILE" ]; then echo "Falto el archivo"; return 1; fi
        local TEMP_WAV="''${FILE%.*}_temp.wav"
        local WHISPER_DIR="$HOME/whisper.cpp"
        # BIN = whisper-cli del PATH (pkgs.whisper-cpp); el build manual
        # (~/whisper.cpp/build) ya no existe en estas máquinas.
        local BIN="$(command -v whisper-cli || echo "$WHISPER_DIR/build/bin/whisper-cli")"
        local MODEL="$WHISPER_DIR/models/ggml-large-v3-turbo.bin"
        local VAD_MODEL="$WHISPER_DIR/models/ggml-silero-v6.2.0.bin"
        if [ ! -f "$VAD_MODEL" ]; then
          echo "Error: No encuentro el modelo VAD en $VAD_MODEL"
          return 1
        fi
        ffmpeg -y -v error -i "$FILE" -ar 16000 -ac 1 -c:a pcm_s16le \
          -af "highpass=f=200,afftdn" "$TEMP_WAV"
        # -of nombra el srt con el nombre ORIGINAL del archivo (sin extensión),
        # no con el del wav temporal: "$FILE.srt" directamente listo para Shotcut.
        "$BIN" -m "$MODEL" -f "$TEMP_WAV" -osrt -of "''${FILE%.*}" -l es \
          --vad -vm "$VAD_MODEL" -vt 0.50 --max-len 1 --split-on-word
        rm "$TEMP_WAV"
        echo "Listo."
      }

      # ONE-SHOT de actualización: flake update + build seco + switch, con
      # guardas. Regla del repo: nunca rebuild sin commit previo y nunca dejar
      # trabajo sin commitear. Con el ISP lento, el build seco avisa ANTES de
      # tocar el sistema si hay descargas gigantes o paquetes rotos.
      update-nixos() {
        local HOST="$1"
        if [ -z "$HOST" ]; then HOST="$(hostname -s | tr -d '0-9')"; fi
        if [ "$HOST" = "nixos" ]; then HOST="pc"; fi
        echo "==> Host: $HOST"
        if [ -n "$(git -C ~/workspaces/nixos-config status --porcelain)" ]; then
          echo "Error: working tree sucio — commit o stash antes de actualizar."
          return 1
        fi
        echo "==> nix flake update..."
        nix flake update nixpkgs || return 1
        echo "==> Build seco (sin tocar el sistema)..."
        sudo nix build --no-link .#nixosConfigurations."$HOST".config.system.build.toplevel \
          || return 1
        echo "==> Switch..."
        sudo nixos-rebuild switch --flake .#"$HOST"
      }
    '';
  };

  home.sessionVariables = {
    OLLAMA_API_BASE = "http://127.0.0.1:11434";
    EDITOR = "nvim";
    COLORTERM = "truecolor";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/.local/share/pnpm/bin"
  ];

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # pipes-rs (los tubos del layout dev; hyprdev lanza con flags propios que
  # sobreescriben estilo y reset, ver hyprdev arriba): modo rgb con hue
  # cíclico (lo más cerca de neón que el programa ofrece; glow real no existe
  # nativamente), tubos gruesos curvos y reset tardío — el default
  # (reset_threshold 0.5) reiniciaba a media pantalla.
  xdg.configFile."pipes-rs/config.toml".text = ''
    bold = true
    color_mode = "rgb"
    rainbow = 4
    delay_ms = 20
    inherit_style = false
    kinds = ["curved", "heavy"]
    num_pipes = 3
    reset_threshold = 0.95
    turn_chance = 0.12
  '';

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
