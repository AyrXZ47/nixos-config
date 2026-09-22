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

      # netrunner: btop y nvtop en 2 ventanas kitty INDEPENDIENTES, btop en
      # ESTA terminal (se reutiliza con `exec`) y nvtop en una nueva, SIEMPRE
      # al lado (nunca debajo): `preselect r` es un override de un solo uso del
      # layout dwindle que fuerza que la próxima ventana tileada se abra a la
      # derecha. nvtop se lanza ANTES del exec. El flag de directorio de la
      # versión anterior no existe en kitty 0.48 (kitty salía al instante):
      # ahora `-d`. Cierre en cadena: las 2 ventanas se rastrean por la address
      # de ESTA ventana (capturada antes del exec btop) y el título
      # `netrunner-nvtop`; armadas las 2, si cae cualquiera se cierra la otra.
      netrunner() {
        if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
          echo "Error: Se requiere sesión Hyprland activa."
          return 1
        fi
        local repo="''${1:-$PWD}"
        local runid="$(date +%s)$RANDOM"
        local pidfile="/tmp/netrunner-pids-$runid"
        : > "$pidfile"
        # Address y pid de ESTA ventana ANTES del exec btop: tras el exec su
        # título ya no es rastreable, pero address/pid no cambian.
        local inv_info inv_addr inv_pid
        inv_info="$(hyprctl -j activewindow 2>/dev/null)"
        inv_addr="$(grep -oE '0x[0-9a-f]+' <<<"$inv_info" | head -1)"
        inv_pid="$(grep -oE '"pid": [0-9]+' <<<"$inv_info" | head -1 | grep -oE '[0-9]+')"
        [[ -n "$KITTY_PID" ]] && inv_pid="$KITTY_PID"
        hyprctl dispatch 'hl.dsp.layout("preselect r")' >/dev/null 2>&1
        # El wrapper apunta su pid ANTES del exec kitty (sin carreras de
        # captura) y setsid le da sesión propia: sobrevive a esta shell.
        setsid zsh -c 'pidf=$1; dir=$2; print -r -- $$ >> "$pidf"; exec kitty -d "$dir" -T netrunner-nvtop zsh -ic nvtop' \
          netrunner-spawn "$pidfile" "$repo" >/dev/null 2>&1 &
        # Watcher en sesión propia ANTES del exec: sobrevive a esta shell. Se
        # arma con las 2 arriba y, al bajar de 2, cierra la que siga por PID
        # (nunca `closewindow` por selector: cae a la ventana activa si no
        # matchea). Timeout de arranque ~30 s por si nvtop nunca aparece.
        setsid zsh -f -c '
          inv=$1; invpid=$2; pidfile=$3; armed=0; n=0
          while :; do
            sleep 1
            out=$(hyprctl -j clients 2>/dev/null)
            a=0
            if grep -q "\"address\": \"$inv\"" <<<"$out"; then a=$((a+1)); fi
            if grep -q "\"title\": \"netrunner-nvtop\"" <<<"$out"; then a=$((a+1)); fi
            if (( a == 2 )); then
              armed=1
            elif (( armed == 1 )); then
              kill $(cat "$pidfile" 2>/dev/null) $invpid 2>/dev/null
              exit 0
            elif (( ++n > 30 )); then
              exit 0
            fi
          done
        ' netrunner-watch "$inv_addr" "$inv_pid" "$pidfile" >/dev/null 2>&1 &
        exec btop
      }

      # `hyprdev [directorio-repo]` — geometría de trabajo en 4 ventanas kitty
      # INDEPENDIENTES que Hyprland tilea (los gaps dejan ver el wallpaper):
      # esta terminal se REUTILIZA como opencode (`exec`) y solo se abren 3
      # nuevas (nvim, shell libre, pipes-rs). opencode va en la ventana
      # INVOCADORA porque al tilear es la que casi no se redimensiona: opencode
      # se rompe si nace/queda en una terminal estrecha. Clase por defecto
      # `kitty` para que el dedupe de Caelestia las colapse a UN icono. Cierre
      # en cadena tipo IDE: las 4 se rastrean por título
      # `hyprdev-<runid>-<rol>` (-T) más la address de ESTA ventana capturada
      # antes del exec opencode; armadas las 4, si cae cualquiera se cierran
      # las demás.
      hyprdev() {
        if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
          echo "Error: Se requiere sesión Hyprland activa."
          return 1
        fi
        local repo="''${1:-$PWD}"
        local runid="$(date +%s)$RANDOM"
        local pidfile="/tmp/hyprdev-pids-$runid"
        : > "$pidfile"
        # Address y pid de ESTA ventana ANTES del exec opencode: tras el exec
        # su título ya no es rastreable, pero address/pid no cambian.
        local inv_info inv_addr inv_pid
        inv_info="$(hyprctl -j activewindow 2>/dev/null)"
        inv_addr="$(grep -oE '0x[0-9a-f]+' <<<"$inv_info" | head -1)"
        inv_pid="$(grep -oE '"pid": [0-9]+' <<<"$inv_info" | head -1 | grep -oE '[0-9]+')"
        [[ -n "$KITTY_PID" ]] && inv_pid="$KITTY_PID"
        # El wrapper apunta su pid ANTES del exec kitty (sin carreras de
        # captura) y setsid le da sesión propia: sobrevive a esta shell.
        spawn() {
          local role="$1"; shift
          setsid zsh -c 'pidf=$1; dir=$2; title=$3; shift 3; print -r -- $$ >> "$pidf"; exec kitty -d "$dir" -T "$title" "$@"' \
            hyprdev-spawn "$pidfile" "$repo" "hyprdev-$runid-$role" "$@" >/dev/null 2>&1 &
        }
        spawn nvim zsh -ic nvim
        spawn free zsh
        spawn pipes zsh -ic "pipes-rs -k heavy,dots,sus --rainbow 0 --palette darker -d 50 -r 0"
        # Watcher en sesión propia ANTES del exec: sobrevive a esta shell. Se
        # arma con las 4 arriba y, al bajar de 4, cierra las que sigan.
        # `hyprctl dispatch closewindow address:<a>` (legacy) ya no se parsea
        # con la config Lua, y `hl.dsp.window.close` con selector cae a la
        # ventana ACTIVA cuando no matchea (footgun). Por eso se matan los PID
        # kitty propios: exactos y sin tocar ninguna ventana ajena.
        setsid zsh -f -c '
          run=$1; inv=$2; invpid=$3; pidfile=$4; armed=0; n=0
          while :; do
            sleep 1
            out=$(hyprctl -j clients 2>/dev/null)
            a=$(grep -c "\"title\": \"hyprdev-$run-" <<<"$out")
            if grep -q "\"address\": \"$inv\"" <<<"$out"; then a=$((a+1)); fi
            if (( a == 4 )); then
              armed=1
            elif (( armed == 1 )); then
              kill $(cat "$pidfile" 2>/dev/null) $invpid 2>/dev/null
              exit 0
            elif (( ++n > 30 )); then
              exit 0
            fi
          done
        ' hyprdev-watch "$runid" "$inv_addr" "$inv_pid" "$pidfile" >/dev/null 2>&1 &
        cd "$repo" || return 1
        exec opencode
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
