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

      # Parte la terminal en dos: btop (55%, izquierda) y nvtop (45%,
      # derecha). La versión con hyprctl dispatch layoutmsg/exec dejó de
      # funcionar con la config Lua (el dispatch legacy no se parsea) y solo
      # abría btop.
      netrunner() {
        if [[ -z "$WEZTERM_PANE" ]]; then
          echo "Error: Se requiere WezTerm activo."
          return 1
        fi
        wezterm cli split-pane --pane-id "$WEZTERM_PANE" --right --percent 45 -- zsh -ic nvtop
        exec btop
      }

      dev() {
        if [[ -z "$WEZTERM_PANE" ]]; then
          echo "Error: Se requiere WezTerm activo."
          return 1
        fi
        # Uso: dev [directorio-repo] — si se pasa, entra al repo antes de partir paneles.
        # Layout: arriba 80% (nvim 15% a la izquierda + opencode 85% a la
        # derecha) y abajo 20% partido en vertical con pipes-rs (15% del ancho)
        # y terminal git libre (85%).
        local repo="''${1:-}"
        [[ -n "$repo" ]] && { cd "$repo" || return 1; }
        local PANE_BOTTOM_BLOCK=$(wezterm cli split-pane --pane-id "$WEZTERM_PANE" --bottom --percent 20)
        local PANE_OPENCODE=$(wezterm cli split-pane --pane-id "$WEZTERM_PANE" --right --percent 85 -- zsh -ic "opencode")
        local PANE_PIPES=$(wezterm cli split-pane --pane-id "$PANE_BOTTOM_BLOCK" --left --percent 15 -- zsh -ic "pipes-rs")
        echo "nvim\r" | wezterm cli send-text --pane-id "$WEZTERM_PANE"
      }

      # `dev` pero con VENTANAS wezterm independientes que Hyprland TILEA
      # (dwindle): el mismo feel de WM que cualquier ventana — se reparten la
      # pantalla sin solaparse y se redimensionan con SUPER+clic — sin el modo
      # DE de un mosaico flotante. El orden del spawn ES el layout: cada
      # ventana parte a la anterior (cascada dwindle) y cada spawn ESPERA a
      # que la anterior mapée (poll por clase-runid, sin sleeps a ciegas: esa
      # era la fragilidad del hyprdev viejo). opencode→free→pipes→nvim:
      # opencode hereda la mitad grande y nvim cierra la cascada con el foco
      # (como dev, donde acabas en nvim). El directorio se hereda con --cwd.
      # Uso: hyprdev [directorio-repo] (sin argumento: el directorio actual).
      hyprdev() {
        if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
          echo "Error: Se requiere sesión Hyprland activa."
          return 1
        fi
        local repo="''${1:-$PWD}"
        local runid="$(date +%s)$RANDOM"
        local pidfile="/tmp/hyprdev-pids-$runid"
        (
          # spawn: el wrapper apunta su pid ANTES del exec (sin carreras de
          # captura) y setsid le da sesión propia: los clientes de wezterm
          # start son niñeros de su ventana (bloquean hasta que cierra y
          # mueren con el panel que los lanzó, arrastrándola); en sesión
          # propia sobreviven al kill del panel de origen. >/dev/null: el tty
          # del panel muere antes que los clientes y un write a pty cerrado
          # mataría por SIGPIPE.
          spawn() {
            setsid zsh -c "echo \$\$ >> '$pidfile'; exec wezterm start --cwd '$repo' --class hyprdev-$1-$runid -- $2" >/dev/null 2>&1 &
          }
          waitmap() {
            local n=0
            while (( n < 100 )); do
              hyprctl -j clients 2>/dev/null | grep -q "\"class\": \"hyprdev-$1-$runid\"" && return 0
              sleep 0.1
              (( n++ ))
            done
          }
          spawn opencode 'zsh -ic "opencode"'; waitmap opencode
          spawn free 'zsh';                   waitmap free
          spawn pipes 'zsh -ic "pipes-rs"';   waitmap pipes
          spawn nvim 'zsh -ic "nvim; exec zsh"'; waitmap nvim
          # Cierre en cadena gobernado por la terminal free: su cierre (exit/
          # ctrl-d) mata a los clientes supervivientes (matar el cliente mata
          # su ventana). Los crashes o salidas de opencode/pipes/nvim SOLO
          # cierran su propia ventana: opencode tiene un bug upstream de
          # segfault en resize (Bun/OpenTUI, issue #38199) y no debe tumbar la
          # sesión. Se arma cuando las 4 están mapeadas y expira si nunca se
          # armaron (spawn fallido).
          setsid zsh -f -c '
            run=$1 pids=$2 armed=0 n=0
            while :; do
              sleep 1
              out=$(hyprctl -j clients 2>/dev/null)
              alive=$(grep -c "\"class\": \"hyprdev-[a-z]*-$run\"" <<<"$out")
              free=$(grep -c "\"class\": \"hyprdev-free-$run\"" <<<"$out")
              if (( alive == 4 )); then armed=1
              elif (( armed == 1 )); then
                if (( free == 0 && alive > 0 )); then
                  kill $(cat "$pids") 2>/dev/null
                  exit 0
                fi
                (( alive == 0 )) && exit 0
              elif (( ++n > 30 )); then
                exit 0
              fi
            done
          ' hyprdev-watch "$runid" "$pidfile" >/dev/null 2>&1 &
        )
        # El panel que invocó el comando quedaría estorbando detrás de las
        # ventanas: se elimina (solo si hyprdev corrió dentro de wezterm).
        # Los waitmap ya garantizan que las 4 ventanas están en el GUI, así
        # que matarlo no puede dejar el GUI en 0 ventanas.
        if [[ -n "$WEZTERM_PANE" ]]; then
          wezterm cli kill-pane --pane-id "$WEZTERM_PANE"
        fi
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

      ytsong() {
        local url=$(wl-paste)
        yt-dlp --no-warnings --no-playlist --extract-audio --audio-format opus --audio-quality 0 \
          -f "bestaudio/best" \
          --embed-metadata --embed-thumbnail --js-runtimes node \
          --cookies-from-browser firefox \
          --extractor-args "youtube:player_client=default,-android_vr" \
          -o "%(uploader)s - %(title)s.%(ext)s" "$url"
      }

      ytlist() {
        local url=$(wl-paste)
        yt-dlp --no-warnings --ignore-errors --extract-audio --audio-format opus --audio-quality 0 \
          -f "bestaudio/best" \
          --embed-metadata --embed-thumbnail --js-runtimes node \
          --cookies-from-browser firefox --download-archive historial_descargas.txt \
          --sleep-requests 1 --sleep-interval 3 --max-sleep-interval 8 \
          --extractor-args "youtube:player_client=default,-android_vr" \
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
