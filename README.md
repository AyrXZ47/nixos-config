# NixOS Configuration — Cyberpunk, Modular, Flake-Driven

[![License: GPL v3](https://img.shields.io/badge/Source%20Code-GPLv3-blue.svg)](LICENSE-SOFTWARE)
[![License: CERN-OHL-S](https://img.shields.io/badge/Hardware-CERN--OHL--S%20v2-orange.svg)](LICENSE-HARDWARE)
[![License: CC BY-SA 4.0](https://img.shields.io/badge/Docs%20%26%20Media-CC%20BY--SA%204.0-lightgrey.svg)](LICENSE-MEDIA)

Personal NixOS configuration, 100% declarative and modular. Cyberpunk-themed,
AMD-powered, Hyprland-driven. Same config runs on a VM, a desktop, a laptop and a
headless server — the idea is that whatever works in the VM works identically on
real hardware.

Built on `nixos-unstable` (nixpkgs pinned in `flake.lock`), Nix flakes, Home Manager,
and a hand-rolled cyberpunk theme (magenta `#ff0066` / cyan `#00f0ff` on deep navy).

## Hosts

| Host     | Role      | Hardware                  | GPU          | Tuning                                    |
| -------- | --------- | ------------------------- | ------------ | ----------------------------------------- |
| `pc`     | Desktop   | Ryzen 5700X               | RX 7600      | `amd_pstate=active`, governor `performance` |
| `laptop` | Mobile    | AMD laptop (ThinkPad-ish) | Integrated   | `amd_pstate=active` (común), governor `powersave`, EPP `balance_power` |
| `server` | Headless  | AMD                       | (none)       | `amd-common` only, no desktop             |
| `vm`     | Virtual   | QEMU/VMware               | virtio/vmwgfx| virtio initrd, LUKS + btrfs subvols      |

Every host is `x86_64-linux`, runs the Zen kernel, enables the `yovick` user with
Home Manager, and stores its mounts in `hosts/<name>/hardware-configuration.nix`
(`disk-by-label` for `pc`/`laptop`/`server`, generated for `vm`).

## Architecture

```
flake.nix              # Entry point — hosts & shared modules
├── hosts/             # Per-machine configuration
│   ├── pc/            # Desktop (Ryzen 5700X + RX 7600)
│   ├── laptop/        # AMD laptop / ThinkPad
│   ├── server/        # Headless server
│   └── vm/            # QEMU/VMware guest
├── modules/
│   ├── apps/          # Applications (system + home)
│   ├── core/          # User & Nix daemon tuning
│   ├── desktop/       # Hyprland (system + home), rofi
│   ├── hardware/      # AMD tuning (common, desktop, laptop)
│   └── theming/       # Cursor/fonts, Plymouth, wallpapers
├── home/              # Home Manager entry point (user `yovick`)
├── assets/            # Wallpapers (mp4 via mpvpaper) & fastfetch logo
└── bootstrap.sh       # One-shot deploy on a fresh machine
```

`flake.nix` defines a single `mkHost` wrapper: every host gets Home Manager (user
`yovick` + `home/default.nix`), the Nix optimization module, and then its own
`hosts/<name>/configuration.nix` on top.

## Software

### Desktop
- **Hyprland** — dwindle layout, 5px/10px gaps, 12px rounding, blur (12/3 passes),
  shadows, opacity 0.8/0.75, overshoot/bounce animations, animated gradient borders.
- **SDDM** — Wayland, `sddm-astronaut` "cyberpunk" theme.
- **wayle** — right-side cyberpunk bar: workspaces, clock, notifications, battery,
  clipboard, wallpaper, dashboard (lock/logout/reboot/poweroff).
- **rofi** — drun/run launchers with a custom `cyberpunk.rasi` theme.
- **hyprlock / hypridle**, polkit-gnome agent, `cliphist` clipboard manager,
  `hyprshot` screenshots, animated wallpapers via **mpvpaper** (looped mp4).

### Shell & Terminal
- **Zsh** + Oh My Zsh (`git`, `sudo`) + **powerlevel10k** (instant prompt) +
  autosuggestions + syntax highlighting; word-wise bindings; fzf integration.
- **WezTerm** — Cyberdyne scheme, JetBrains Mono Nerd, 14px, 0.66 background
  opacity, no decorations, hidden tab bar, maximizes on start.
- Aliases: `cat→bat`, `du→dust`, `ps→procs`, `top→btop`, `tree→eza --tree`.
- **fastfetch** on terminal open, with the repo logo via kitty image protocol.

### Editor & Dev
- **Neovim** (LazyVim) — `cyberneon` theme, smear-cursor, render-markdown,
  obsidian.nvim (`~/Sync/Notes`), img-clip paste, ollama.nvim (`qwen3.6:35b-a3b-mtp-q4_K_M`),
  mason, rainbow-delimiters, treesitter-context, lsp_lines; LSPs: lua-language-server,
  stylua, typescript-language-server, pyright, gcc.
- **OpenCode** + **Ollama** (local AI stack, `OLLAMA_API_BASE` set).
- **Ollama version pin** (`modules/apps/ollama-bin.nix`, solo pc): instala el
  binario oficial v0.32.12 desde los tarballs de la release (base + addon ROCm)
  porque nixpkgs-unstable va con días de retraso y modelos nuevos (ej. qwen3.8)
  exigen releases recientes. Laptop sigue con `ollama-vulkan` de nixpkgs. Para
  subir de versión: cambiar `version` y los dos `sha256` en el módulo (hashes del
  API de GitHub).

### Gaming
- **Steam** (gamescope session, Remote Play + dedicated server + LAN transfers
  firewalls, protontricks) with **Proton GE**.
- **GameMode**, **MangoHud**, **Gamescope**, **ProtonUp-Qt**, Wine (Wayland),
  Winetricks.

### Toolchains (system-wide)
- **Android**: `android-tools` (adb/fastboot).
- **Arduino**: `arduino-cli`.
- **Embedded (ESP32 / STM32)**: `esptool`, `stm32flash`, `openocd` (debug/flash).
- **Raspberry Pi**: `rpiboot` (mass-storage boot), `raspberrypi-eeprom`,
  `picocom` (serial console).
- **Rust**: `rustup` (toolchains on demand). **JS**: `pnpm`.
- **Flatpak** (pc/laptop/vm): service enabled + Flathub remote auto-added at first
  login (`flatpak-flathub.service`, idempotent oneshot).

### Applications
Productivity: LibreOffice, Obsidian, KeePassXC, Syncthing, Firefox (autohide
toolbox via userChrome.css).
Creative: Blender, Krita, GIMP, Inkscape, Audacity, Mixxx, Shotcut, OBS Studio,
VLC.
Engineering: KiCad, FreeCAD, OpenRocket, OpenMotor, Qucs-S, SimulIDE,
Logisim-Evolution, Octave.
Utilities: 1Password CLI, `gh`, btop, cava, pipes-rs, scrcpy, virt-manager,
proton-vpn, openrgb, qpwgraph, dolphin, kdeconnect, tor-browser, yt-dlp.
Fun: `cbonsai`.

### Edición de vídeo
- **Editor: Shotcut** (ya en `modules/apps/common-packages.nix`). Aceleración GPU
  verificada en `pc` (RX 7600): VA-API con radeonsi — H.264/HEVC/VP9/AV1 con
  decode Y encode por hardware.
- **Por qué NO DaVinci Resolve (free)**: H.264/H.265 se procesan por CPU (el
  hardware accel es de Studio y en Linux NVIDIA-only). Por eso el flujo previo
  exigía convertir a mov (ProRes → cientos de GB). Instalarlo en NixOS es
  posible (existe en nixpkgs) pero no arregla los codecs.
- **Por qué NO** Filmora (no existe build Linux — solo Windows/macOS/móvil),
  ni kdenlive (descartado), ni Blender VSE (sin LUTs reales, export por CPU).
- Verificación VA-API (smoke test real en esta máquina):

```bash
$ ffmpeg -hide_banner -f lavfi -i testsrc=duration=1:size=640x360:rate=30 \
    -vaapi_device /dev/dri/renderD128 -vf 'format=nv12,hwupload' \
    -c:v h264_vaapi -f null -
Output #0, null, to 'pipe:':
  Metadata:
    encoder         : Lavf62.12.102
  Stream #0:0: Video: h264 (High), vaapi(tv, progressive), 640x360 [SAR 1:1 DAR 16:9], q=2-31, 30 fps, 30 tbn
    Metadata:
      encoder         : Lavc62.28.102 h264_vaapi
[out#0/null @ 0x5fc4b4c0f280] video:16KiB audio:0KiB subtitle:0KiB other streams:0KiB global headers:0KiB muxing overhead: unknown
frame=   30 fps=0.0 q=-0.0 Lsize=N/A time=00:00:00.96 bitrate=N/A speed=28.3x elapsed=0:00:00.03
```

- Tip: exportar a **AV1 por hardware** (la RX 7600 lo soporta) → archivos mucho
  más pequeños a calidad similar.
- Si Shotcut crasheara en NixOS: primero desactivar hardware decode en
  **Ajustes → Reproductor** y reportarlo al planner (ola futura) — no parchear
  a mano ni cambiar de editor.

## Performance & Tuning

### Nix daemon (`modules/core/nix-optimization.nix`)
- `cores = 0`, `max-jobs = auto` — uses every core/thread.
- CPU/IO scheduler `idle` while building → no freezes on the desktop.
- Substituters: `cache.nixos.org` + `hyprland.cachix.org` (avoids compiling Hyprland).
- Daily GC (pure store GC) + daily `trim-generations` service keeping at most 3
  generations by COUNT (`nix-env --delete-generations +3`); automatic store
  optimisation. Not age-based — 20 rebuilds in 3 days still leaves exactly 3.

### Hardware (`modules/hardware/`)
- Zen kernel everywhere, AMD microcode, `hardware.graphics` 32-bit.
- `zramSwap` at 50% memory.
- Common kernel params: `quiet splash loglevel=3 nowatchdog split_lock_detect=off`.
- Desktop: `amd_pstate=active`, `mitigations=off`, `max_cstate=1`, `performance`
  governor, amdgpu in initrd (early KMS).
- Laptop: `powersave` governor + EPP `balance_power` (boost bajo demanda, reposo
  profundo), sin `max_cstate=1`, touchpad libinput (clickfinger, natural scrolling,
  RMI4 via `psmouse.synaptics_intertouch=1`), iio sensors, NetworkManager with iwd.
- VM: virtio/VMware guest modules, QEMU guest agent, SPICE.

### Fingerprint (`modules/hardware/fingerprint.nix`)
Activa `services.fprintd` + libfprint (el sensor del laptop, Synaptics 06cb:00bd,
lo cubre libfprint base; algunos Goodix/Validity necesitan driver TOD).

Para **registrar huellas** cuando se te antoje (por sensor, por usuario):

```bash
sudo fprintd-enroll          # pide pass y registra el índice derecho
sudo fprintd-enroll -f left-index-finger   # otro dedo: -f left-index-finger
fprintd-list yovick          # ver huellas registradas
fprintd-delete yovick        # borrar TODAS las huellas del usuario
fprintd-verify               # probar sin PAM de por medio
```

Dónde funciona la huella:
- **sudo** (terminal) — PAM `pam_fprintd`.
- **hyprlock** (bloqueo de pantalla) — fprintd nativo de hyprlock, sin PAM.
- **NO** en SDDM: no tiene UI de huella y `pam_fprintd` bloqueaba el login
  esperando el dedo; el PAM de `login`/`sddm` está desactivado a propósito
  (`fprintAuth = false`).
- PC sin sensor: no pasa nada, todo sigue por contraseña (fprintd no encuentra
  dispositivos y `pam_fprintd` falla rápido).

> Nota: `security.pam.services.<name>.fprintAuth` **defaulta a `true`** cuando
> `services.fprintd.enable` está activo, así que todos los servicios PAM la
> heredan salvo que se apague explícitamente.

### Autoscroll con botón central (`modules/hardware/wheeltani.nix`)
Replica el trackpoint del laptop en el PC (solo activo en `pc`): mantener el
**botón central** y mover el mouse scrolla en esa dirección (la velocidad
sigue la distancia al punto de presión). Lo hace **wayland-wheeltani**
(input flake, no va en nixpkgs), daemon evdev→uinput que graba el mouse físico
y emite un mouse virtual — funciona con cualquier compositor Wayland.

- El mouse se empareja por USB ids (`device.vendorId`/`productId`), así
  sobrevive reinicios y cambios de puerto. PC: SHARKOON vía su dongle
  **`0c45:fefe`** (OJO: no usar el ID de lsusb de la base de carga `1ea7:0064`,
  no expone nodo de input; el ID correcto se ve con
  `wayland-wheeltani --list-devices` o `/proc/bus/input/devices`).
- Permisos: `yovick` en el grupo `input` (leer eventX + EVIOCGRAB) y udev rule
  que da el grupo `input` sobre `/dev/uinput`.
- Servicio: `systemd --user` (`wayland-wheeltani.service`), arranca con la
  sesión gráfica. Ver logs: `journalctl --user -u wayland-wheeltani -f`.
- Un click corto sin mover = click central normal (paste en X11, etc.).

**Activar en otro host** (laptop nueva con mouse genérico, etc.): el daemon
solo empareja UN mouse por USB ids (no hay modo "cualquier mouse", verificado
en el source), así que por host se declaran los IDs del mouse que le toque:

1. Importar `../../modules/hardware/wheeltani.nix` en `hosts/<host>/configuration.nix`.
2. `modules.hardware.wheeltani = { enable = true; device = { vendorId = "vvvv"; productId = "pppp"; }; }`
   — los IDs NO salen de `lsusb` a ciegas: ratones inalámbricos exponen el nodo
   de puntero con los IDs del **dongle** (busca el "2.4G Dongle"/"2.4G Mouse" en
   `wayland-wheeltani --list-devices` o `/proc/bus/input/devices`).
3. Rebuild. El daemon espera a que exista el mouse que matchea y lo agarra al
   vuelo (hotplug); un mouse sin IDs asignados no se toca. Hosts sin sesión
   gráfica (server) no aplican: el servicio arranca con `graphical-session.target`.

### Boot
- **systemd-boot** on every host; `boot.initrd.systemd` + Plymouth (`ironman`
  theme from `adi1090x-plymouth-themes`); quiet boot.
- PipeWire (ALSA/Pulse/JACK) + rtkit for pro audio; ZRAM swap.

## Keybindings (Hyprland)

| Keys | Action |
| ---- | ------ |
| `SUPER Backspace` | Terminal (wezterm) |
| `SUPER A` / `SUPER R` | rofi drun / run |
| `SUPER Delete` | Kill window |
| `SUPER M` | Exit session |
| `SUPER V` | Toggle floating |
| `SUPER J` | Toggle split |
| `SUPER arrows` / `SUPER SHIFT arrows` | Focus / move window |
| `SUPER 1-9` / `SUPER SHIFT 1-9` | Switch / move to workspace |
| `SUPER W` | *time-to-work*: Mixxx → Obsidian → Firefox on ws 1-3 |
| `SUPER N` | *netrunner*: btop + nvtop split |
| `SUPER SPACE` | Switch keyboard layout (latam/us) |
| `SUPER L` | Lock session |
| `SUPER P` variants | Screenshot region (`SUPER SHIFT P`) / window (`SUPER ALT P`) / screen (`SUPER P`) |
| Media keys | Volume (wpctl), mic mute, brightness (brightnessctl) |

## Custom Commands

- `dev [repo]` — full dev workspace in WezTerm panes (editor, AI, cava, pipes);
  con directorio opcional entra al repo antes de partir paneles.
- `netrunner` — nvtop + btop split.
- `SecDesk` / `Mirror` (+ `_WiFi <ip>`) — scrcpy tablet mirroring, 85 fps,
  h265/opus, virtual 1920x1080 display for a secure desk setup.
- `ytsong` / `ytlist` — download audio from clipboard (yt-dlp, cookies from Firefox).
- `estabilizar_clips` / `estabilizar_clips_gpu` — re-encode clips to CFR 30 (CPU x264
  or VA-API h264) for stable editing.
- `subtitular <video>` — Whisper (whisper.cpp) Spanish subtitles with VAD.

## Installation on a New Machine

1. Install NixOS with the official installer (any partitioning).
2. `git clone https://github.com/<you>/nixos-config && cd nixos-config`
3. `./bootstrap.sh <host>` — regenerates `hardware-configuration.nix` from the real
   disks, runs `sudo nixos-rebuild switch --flake .#<host>`, and commits the file.

That's it — no manual hardware step, no `gh`/GitHub auth required (the repo is public
and only the local file is touched). First login uses `initialPassword` (see
`modules/core/user.nix`); change it with `passwd`.

## Adding a New Host

1. `cp -r hosts/vm hosts/<name>`
2. Edit `hosts/<name>/configuration.nix`: hostname, hardware module imports
   (`modules/hardware/*`), desktop enablement.
3. Register it in `flake.nix` under `nixosConfigurations` with `mkHost`.
4. `./bootstrap.sh <name>`.

## nix-on-droid (celular/tablet)

Config independiente para Android (app de nix-on-droid / Termux), sincronizada
desde el repo: flake propio en `nix-on-droid/` (`nixOnDroidConfigurations.default`),
**no** entra en `nix flake check` de la raíz. Reutiliza los módulos home del repo
(shell, git, neovim) via home-manager.

Para aplicar cambios, en el celular, **dentro del directorio del flake**
`nix-on-droid/` — la raíz del repo es el flake de NixOS y `--flake .` desde
ahí evalúa el flake equivocado (falla con "does not provide attribute
`nixOnDroidConfigurations...`"):

```bash
git -C ~/nixos-config pull
cd ~/nixos-config/nix-on-droid
nix-on-droid switch --flake .#default
```

**Ojo con los pins** (ver comentarios en `nix-on-droid/flake.nix` antes de tocarlos):
nixpkgs `nixos-25.11` + home-manager `release-25.11` (glibc <2.42) y nix-on-droid
anclado al master pre-PR #529 (proot 2024-05-04 con rutas que el APK ya trae en el
store). Juntos hacen que el switch active sin pasos extra. Unstable (glibc ≥2.42)
rompe la activación del proot — no es conservadurismo, es el techo actual; se
destraba cuando el PR #529 (proot nuevo) esté mergeado de forma utilizable.

**opencode** no vive en el profile nix: el output standalone no viene de la
caché binaria, el store del celular lo perdía y el profile quedaba con symlink
muerto (`command not found` sin error). Se instala por activación de home-manager
desde el tarball verificado commiteado al repo (`nix-on-droid/opencode-1.18.16.tar.gz`,
60 MB — el asset upstream fue re-subido y su CDN servía hashes distintos por región),
extrayéndolo a `~/.opencode/bin` con `patchelf` que re-apunta el interpreter ELF
al loader de glibc del store (el binario standalone pide `/lib/ld-linux-aarch64.so.1`,
inexistente en nix-on-droid). Autocurable: cada switch lo reinstala. Al subir de
versión: reemplazar el tarball y ajustar la versión en `configuration.nix`.

**Gotchas del entorno proot** (por qué algunas cosas del PC no van aquí):
- `btop` no: proot falsifica `/proc/stat` con un stub mínimo que solo soporta `htop`.
- `fastfetch` corre con su config por defecto (la del PC usa logo PNG y líneas anchas).
- `dev`/`netrunner` requieren WezTerm — no existe en Android (usa la terminal de la app).
- `ping` funciona solo si el SELinux del fabricante permite raw sockets.
- El env default de nix-on-droid no trae ni `grep`: el flake añade gnugrep, gnused,
  gnutar, gzip, bzip2, xz, zip, findutils, diffutils, procps, killall.

## Day-to-Day

```bash
sudo nixos-rebuild switch --flake .#<host>   # apply system + home changes
home-manager switch --flake .#<host>          # Home Manager only
nix flake update                              # bump inputs
nix flake check                               # evaluate all hosts
```

## Security Notes

- **Nothing secret is committed**: no SSH keys, no tokens, no credentials.
- `initialPassword` only applies when the `yovick` user is created (first boot) and
  never overrides an existing password.
- **For people cloning this repo:** the config builds the `yovick` user with that
  initial password — rename the user (`flake.nix`, `modules/core/user.nix`), hostname,
  and `git remote` to your own, then change the password after first login. Only the
  repo owner (or granted collaborators) can push; anyone can clone and fork.

## License

- **Source code** (`flake.nix`, `modules/`, `hosts/`, `home/`): [GNU GPLv3](LICENSE-SOFTWARE)
- **Hardware** (`hardware/`): [CERN-OHL-S v2](LICENSE-HARDWARE)
- **Documentation & media** (`docs/`, `assets/`): [CC BY-SA 4.0](LICENSE-MEDIA)
