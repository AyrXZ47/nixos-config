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

    # autosuggestions/syntax-highlighting NO van acá: los booleanos
    # `autosuggestion.enable` y `syntaxHighlighting.enable` de arriba ya las
    # cargan; declararlas de nuevo las sourceaba dos veces.
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    initContent = ''
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

      # WezTerm tenía detect_password_input: cambiaba el cursor por un candado
      # rojo al detectar un prompt de contraseña (eco apagado). kitty no tiene
      # esa detección; se aproxima con su color-stack: al lanzar `sudo` se
      # empuja la paleta y se pinta el cursor de rojo (OSC 30001 + OSC 21), y
      # se restaura al volver al prompt (OSC 30101). Solo en kitty; en otras
      # terminales (nix-on-droid) no se emite nada.
      _sudo_cursor_preexec() {
        [[ -n $KITTY_WINDOW_ID ]] || return 0
        case $1 in
          sudo|sudo\ *) printf '\e]30001\e\\\e]21;cursor=rgb:ff/00/3c\e\\'; _sudo_cursor_pushed=1 ;;
        esac
      }
      _sudo_cursor_precmd() {
        [[ -n $_sudo_cursor_pushed ]] || return 0
        unset _sudo_cursor_pushed
        printf '\e]30101\e\\'
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook preexec _sudo_cursor_preexec
      add-zsh-hook precmd _sudo_cursor_precmd

      bindkey "^[[1;5C" forward-word
      bindkey "^[[1;5D" backward-word
      bindkey "^H" backward-delete-word
      bindkey "^[[3;5~" delete-word

      [ -f /usr/share/fzf/shell/completion.zsh ] && source /usr/share/fzf/shell/completion.zsh
      [ -f /usr/share/fzf/shell/key-bindings.zsh ] && source /usr/share/fzf/shell/key-bindings.zsh

      # fastfetch: UNA vez por ventana NUEVA de kitty. El marker vive en
      # XDG_RUNTIME_DIR y lleva KITTY_PID + KITTY_WINDOW_ID: los shells anidados
      # de la misma ventana no lo repiten, y los ids de ventana de kitty son
      # por OS-window (dos kitty distintas pueden repetir id), así que el PID
      # desambigua. Se limpia solo al cerrar sesión. hyprdev y netrunner
      # exportan FASTFETCH_SKIP=1 en las ventanas que abren: ahí el banner
      # taparía la geometría de trabajo. Fuera de kitty (nix-on-droid) no hay
      # window id estable: se muestra una vez por shell, como antes.
      if [[ -z $FASTFETCH_SKIP ]] && command -v fastfetch >/dev/null; then
        if [[ -z $KITTY_WINDOW_ID ]]; then
          fastfetch
        else
          _ff_marker="''${XDG_RUNTIME_DIR:-/tmp}/fastfetch-kitty-$KITTY_PID-$KITTY_WINDOW_ID"
          if [[ ! -e $_ff_marker ]]; then
            touch "$_ff_marker"
            fastfetch
          fi
          unset _ff_marker
        fi
      fi

      # netrunner: btop en ESTA terminal (se reutiliza con `exec`) y nvtop en
      # una kitty nueva, SIEMPRE al lado (nunca debajo): `preselect r` es un
      # override de un solo uso del layout dwindle que fuerza que la próxima
      # ventana tileada se abra a la derecha. nvtop se lanza ANTES del exec.
      # `-d` es el flag de directorio de kitty 0.48+ (el viejo `--directory`
      # no existe: kitty salía al instante). Sin watchers ni PID tracking: el
      # usuario cierra las dos ventanas a mano. FASTFETCH_SKIP=1: la ventana
      # nueva es de trabajo, el banner taparía nvtop.
      netrunner() {
        if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
          echo "Error: Se requiere sesión Hyprland activa."
          return 1
        fi
        local repo="''${1:-$PWD}"
        hyprctl dispatch 'hl.dsp.layout("preselect r")' >/dev/null 2>&1
        # setsid: la ventana nueva sobrevive a esta shell (el `exec btop` de
        # abajo reemplaza este proceso).
        setsid env FASTFETCH_SKIP=1 kitty -d "$repo" -T netrunner-nvtop zsh -ic nvtop >/dev/null 2>&1 &
        exec btop
      }

      # `opencode-pair [puerto]` — el `/pair` normal bindea el servicio a
      # localhost, así que el QR no abre desde el celular. Este helper fija el
      # hostname del servicio a la IP de Tailscale, lo reinicia y recién ahí
      # muestra el QR. Requiere que el teléfono esté en la misma tailnet.
      opencode-pair() {
        local ip port
        ip="$(tailscale ip -4 2>/dev/null | head -1)"
        if [[ -z "$ip" ]]; then
          echo "Error: Tailscale no está arriba."
          return 1
        fi
        port="''${1:-4096}"
        opencode service set hostname "$ip"
        opencode service set port "$port"
        opencode service restart
        opencode pair
      }

      # `hyprdev [directorio-repo]` — geometría de trabajo en 3 ventanas kitty
      # INDEPENDIENTES que Hyprland tilea (los gaps dejan ver el wallpaper):
      # esta terminal se REUTILIZA como OpenCode (`exec`) y solo se abren 2
      # nuevas (nvim, shell libre). OpenCode va en la ventana
      # INVOCADORA porque al tilear es la que casi no se redimensiona: la TUI
      # necesita ancho para el sidebar y el composer. Clase por defecto
      # `kitty` para que el dedupe de Caelestia las colapse a UN icono. Sin
      # watchers ni PID tracking: el usuario cierra las ventanas a mano.
      # FASTFETCH_SKIP=1 en las ventanas nuevas: son de trabajo.
      hyprdev() {
        if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
          echo "Error: Se requiere sesión Hyprland activa."
          return 1
        fi
        local repo="''${1:-$PWD}"
        # setsid: las ventanas nuevas sobreviven a esta shell (el `exec
        # opencode` de abajo reemplaza este proceso).
        setsid env FASTFETCH_SKIP=1 kitty -d "$repo" -T hyprdev-nvim zsh -ic nvim >/dev/null 2>&1 &
        setsid env FASTFETCH_SKIP=1 kitty -d "$repo" -T hyprdev-shell zsh >/dev/null 2>&1 &
        cd "$repo" || return 1
        exec opencode --auto
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
          --cookies-from-browser brave \
          --extractor-args "youtube:player_client=tv_downgraded,tv,visionos" \
          -o "%(uploader)s - %(title)s.%(ext)s" "$url"
      }

      ytlist() {
        local url="$(yt_url "$1")"
        yt-dlp --no-warnings --ignore-errors --extract-audio --audio-format opus --audio-quality 0 \
          -f "bestaudio/best" \
          --embed-metadata --embed-thumbnail --js-runtimes node \
          --cookies-from-browser brave --no-overwrites \
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

      # Re-encode a CFR 30 para Shotcut. Solo el ENCODE va en GPU (h264_vaapi).
      # El DECODE no puede ir en VA-API: con radeonsi el decoder h264 solo crea
      # superficies para anchos alineados (720p sí, 576/832 no) y revienta con
      # "Failed setup for format vaapi" -> -38; el fallback a CPU deja el frame
      # en RAM y scale_vaapi ya no puede conectarlo ("Impossible to convert").
      # Decodificando a RAM y subiendo con hwupload funciona en cualquier
      # resolución a ~20x, indistinguible del decode en GPU (el cuello es el
      # encoder). NUNCA añadir transpose propio: ffmpeg ya aplica la rotación
      # del Display Matrix, y rotar otra vez deja los verticales acostados.
      estabilizar_clips_gpu() {
        mkdir -p listos_para_editar
        for f in *.mp4(N) *.MP4(N) *.mov(N) *.MOV(N) *.mkv(N) *.MKV(N); do
          [[ -f "listos_para_editar/$f" ]] && continue
          # -c:a copy solo es seguro con AAC; el resto se re-encoda a AAC.
          local acodec="$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$f" 2>/dev/null)"
          local amap=(-c:a copy)
          [[ -n "$acodec" && "$acodec" != "aac" ]] && amap=(-c:a aac -b:a 192k)
          if ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer \
            -of csv=p=0 "$f" | grep -qE "smpte2084|arib-std-b67"; then
            # El tonemap NO puede ir en GPU en esta máquina: el ffmpeg de nixpkgs
            # va sin libplacebo (--disable-libplacebo) y tonemap_vaapi aborta con
            # "VAAPI driver doesn't support HDR" en radeonsi. zscale+tonemap en
            # CPU es vectorizado y barato; el encode sigue en GPU.
            echo "HDR ($f): tonemap en CPU, encode por GPU"
            ffmpeg -init_hw_device vaapi=va:/dev/dri/renderD128 -filter_hw_device va -i "$f" \
              -vf "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=nv12,hwupload" \
              -c:v h264_vaapi -qp 18 -fps_mode cfr -r 30 "$amap[@]" "listos_para_editar/$f"
          else
            echo "SDR ($f): encode por GPU"
            ffmpeg -init_hw_device vaapi=va:/dev/dri/renderD128 -filter_hw_device va -i "$f" \
              -vf "format=nv12,hwupload,scale_vaapi=format=nv12" \
              -c:v h264_vaapi -qp 18 -fps_mode cfr -r 30 "$amap[@]" "listos_para_editar/$f"
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

      # Inverso de `subtitular`: texto -> voz, con las voces neuronales de
      # Microsoft (edge-tts, ver modules/apps/tts.nix). Sale un .mp3 directo
      # para Shotcut. El guion de 2 min tarda ~3 s; el cuello es la red porque
      # el texto viaja a Microsoft — para algo confidencial, no usar esto.
      narravoz() {
        local FILE="$1"
        local VOZ="''${2:-es-MX-DaliaNeural}"
        if [ -z "$FILE" ]; then
          echo "Falta el archivo de texto"
          echo "Uso: narravoz <guion.md|txt> [voz]   (por defecto: es-MX-DaliaNeural)"
          echo "Voces: edge-tts --list-voices | grep es-"
          return 1
        fi
        if [ ! -f "$FILE" ]; then echo "Error: no existe $FILE"; return 1; fi
        local OUT="''${FILE%.*}.mp3"
        edge-tts --voice "$VOZ" --file "$FILE" --write-media "$OUT" || return 1
        echo "Listo: $OUT ($(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")s)"
      }

      # ONE-SHOT de actualización: flake update (TODOS los inputs) + check de
      # evaluación + build seco + switch, con guardas. Regla del repo: nunca
      # rebuild sin commit previo y nunca dejar trabajo sin commitear. Con el
      # ISP lento, el build seco avisa ANTES de tocar el sistema si hay
      # descargas gigantes o paquetes rotos.
      update-nixos() {
        local HOST="$1"
        if [ -z "$HOST" ]; then HOST="$(hostname -s | tr -d '0-9')"; fi
        if [ "$HOST" = "nixos" ]; then HOST="pc"; fi
        # Todo se evalúa/construye contra el repo, no contra el CWD de quien
        # invoca la función (antes un `update-nixos` desde otra carpeta
        # actualizaba un flake que no era).
        cd ~/workspaces/nixos-config || return 1
        echo "==> Host: $HOST"
        if [ -n "$(git status --porcelain)" ]; then
          echo "Error: working tree sucio — commit o stash antes de actualizar."
          return 1
        fi
        echo "==> nix flake update (todos los inputs)..."
        nix flake update || return 1
        echo "==> nix flake check (solo evaluación, sin construir)..."
        nix flake check --no-build || return 1
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

  # ytmusic: cruza la carpeta de musica contra playlists de YT Music y repara los
  # tags/portadas usando el tag PURL (sin re-descargar audio). Ver
  # odd/tasks/music-library.md. mutagen reescribe los comentarios vorbis in-place.
  home.packages = with pkgs; [
    # fpcalc: huella digital de audio (chromaprint). Sirve para confirmar que dos
    # archivos son la misma grabación y no solo el mismo título. En el cache
    # binario de nixpkgs: no compila nada.
    chromaprint
    (writeShellScriptBin "ytmusic" ''
      exec ${python3.withPackages (ps: [ ps.mutagen ps.ytmusicapi ])}/bin/python3 \
        ${./music/ytmusic.py} "$@"
    '')
  ];

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
