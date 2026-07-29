{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

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

      fastfetch

      netrunner() {
        wezterm cli split-pane --right -- nvtop
        btop
      }

      dev() {
        if [[ -z "$WEZTERM_PANE" ]]; then
          echo "Error: Se requiere WezTerm activo."
          return 1
        fi
        local PANE_BOTTOM_BLOCK=$(wezterm cli split-pane --pane-id "$WEZTERM_PANE" --bottom --percent 35)
        local PANE_OPENCODE=$(wezterm cli split-pane --pane-id "$WEZTERM_PANE" --right --percent 40 -- zsh -ic "headroom wrap opencode")
        local PANE_CAVA=$(wezterm cli split-pane --pane-id "$PANE_BOTTOM_BLOCK" --right --percent 50 -- zsh -ic "cava")
        local PANE_PIPES=$(wezterm cli split-pane --pane-id "$PANE_BOTTOM_BLOCK" --left --percent 10 -- zsh -ic "pipes-rs")
        local PANE_CLEAN=$(wezterm cli split-pane --pane-id "$PANE_BOTTOM_BLOCK" --bottom --percent 30)
        echo "aider\r" | wezterm cli send-text --pane-id "$PANE_BOTTOM_BLOCK"
        echo "nvim\r" | wezterm cli send-text --pane-id "$WEZTERM_PANE"
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
        yt-dlp --no-playlist --extract-audio --audio-format opus --audio-quality 0 \
          --embed-metadata --embed-thumbnail --js-runtimes node \
          --cookies-from-browser firefox \
          -o "%(uploader)s - %(title)s.%(ext)s" "$url"
      }

      ytlist() {
        local url=$(wl-paste)
        yt-dlp --ignore-errors --extract-audio --audio-format opus --audio-quality 0 \
          --embed-metadata --embed-thumbnail --js-runtimes node \
          --cookies-from-browser firefox --download-archive historial_descargas.txt \
          --sleep-interval 3 --max-sleep-interval 8 \
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
            ffmpeg -vaapi_device /dev/dri/renderD128 -i "$f" \
              -vf "format=nv12,hwupload" -c:v h264_vaapi -qp 18 \
              -fps_mode cfr -r 30 -c:a copy "listos_para_editar/$f"
          fi
        done
      }

      subtitular() {
        local FILE="$1"
        if [ -z "$FILE" ]; then echo "Falto el archivo"; return 1; fi
        local TEMP_WAV="''${FILE%.*}_temp.wav"
        local WHISPER_DIR="$HOME/whisper.cpp"
        local BIN="$WHISPER_DIR/build/bin/whisper-cli"
        local MODEL="$WHISPER_DIR/models/ggml-large-v3-turbo.bin"
        local VAD_MODEL="$WHISPER_DIR/models/ggml-silero-v6.2.0.bin"
        if [ ! -f "$VAD_MODEL" ]; then
          echo "Error: No encuentro el modelo VAD en $VAD_MODEL"
          return 1
        fi
        ffmpeg -y -v error -i "$FILE" -ar 16000 -ac 1 -c:a pcm_s16le \
          -af "highpass=f=200,afftdn" "$TEMP_WAV"
        "$BIN" -m "$MODEL" -f "$TEMP_WAV" -osrt -l es \
          --vad -vm "$VAD_MODEL" -vt 0.50 --max-len 1 --split-on-word
        rm "$TEMP_WAV"
        echo "Listo."
      }

      update-obsidian() {
        if [ -z "$1" ]; then
          echo "Error: Debes proporcionar la version. Ejemplo: update-obsidian 1.13.0"
          return 1
        fi
        local VERSION=$1
        cd ~/obsidian-rpm-fedora || return
        wget "https://github.com/obsidianmd/obsidian-releases/releases/download/v''${VERSION}/obsidian-''${VERSION}.tar.gz" \
          -O ~/rpmbuild/SOURCES/Obsidian-''${VERSION}.tar.gz
        sed -i "s/^Version:.*/Version:        $VERSION/" obsidian.spec
        cp obsidian.spec ~/rpmbuild/SPECS/
        cd ~/rpmbuild/SPECS/ || return
        rpmbuild -ba obsidian.spec
        sudo dnf upgrade -y ~/rpmbuild/RPMS/x86_64/obsidian-''${VERSION}-*.rpm
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
