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
Engineering: KiCad 10 (simulador SPICE embebido + librería de ~50k modelos:
`spice-find` y `spice-get`, ver "KiCad + SPICE" abajo), ngspice, FreeCAD,
OpenRocket, OpenMotor, Qucs-S, SimulIDE, Logisim-Evolution, Octave.
Utilities: 1Password CLI, `gh`, btop, cava, pipes-rs, scrcpy, virt-manager,
proton-vpn, openrgb, qpwgraph, dolphin, kdeconnect, tor-browser, yt-dlp.
Fun: `cbonsai`.

### KiCad + SPICE (circuitos — universidad)

KiCad 10 con simulador SPICE embebido (ngspice via `libngspice`) + la librería
comunitaria [kicad-spice-library](https://github.com/kicad-spice-library/KiCad-Spice-Library)
(~50k modelos: transistores, opamps, diodos, digital, manufacturas). Todo se
instala en los 4 hosts desde `modules/apps/common-packages.nix` (input
`kicad-spice-library` en flake.nix, `flake = false` por ser repo de datos).

- **Ruta fija de la librería** (idéntica en todos los hosts):
  `/run/current-system/sw/share/kicad-spice-library/` (existe por
  `environment.pathsToLink`; el buildEnv de NixOS solo enlaza los share que
  estén listados ahí).
- **Buscar un componente:** `spice-find 2n2222` — muestra variantes y de qué
  `.lib` salen. GUI alternativo: `python3
  /run/current-system/sw/share/kicad-spice-library/Scripts/form_spice.py`
  (config en `~/.config/kicad-spice/`, salidas en `~/spice-output`).
- **Extraer al proyecto:** `cd <proyecto-kicad> && spice-get 2n2222` — crea
  `localSpice.lib` en la carpeta (acumulativo: no duplica modelos ya
  extraídos; corre dentro de cualquier repo con su propia carpeta). Además
  **sanea** los modelos que ngspice rechaza (params metadata de PSpice/LTspice
  tipo `mfg=Philips`, `type=`, `SRC=`, `SYM=` — el motor de KiCad es ngspice,
  mismo error) y **verifica** que el modelo cargue de verdad en ngspice antes
  de escribirlo; si la variante top falla, cae a la siguiente.
- **En KiCad:** directiva SPICE `.include localSpice.lib` en el esquemático y
  el nombre del modelo (ej. `2N2222`) como SPICE model del símbolo. Alternativa
  sin extraer: `.include
  /run/current-system/sw/share/kicad-spice-library/Models/Transistor/BJT/BJT.lib`
  con la misma directiva.
- **ngspice CLI** (v45) instalado para netlists `.cir` por terminal
  (`.tran/.ac/.dc`); KiCad usa el mismo motor embebido.
- **Actualizar la librería** cuando el repo upstream agregue modelos:
  `nix flake update kicad-spice-library && sudo nixos-rebuild switch
  --flake .#<host>`.
- El GUI upstream se parchea al empaquetar (config.json → home y rutas Linux;
  el original escribe junto al script —store de solo lectura— y trae rutas
  Windows). `ponytail:` techo conocido — si upstream lo arregla, quitar el
  parche en el overlay `spiceLibraryOverlay`.

### Cisco Packet Tracer (redes — universidad)

Simulador de redes de Cisco (Cisco Networking Academy). Paquete de nixpkgs
(`cisco-packet-tracer_9`, **9.0.0**, AppImage estándar que `appimageTools`
empaqueta sin hacks), **activo en los hosts gráficos** (pc/laptop/vm) con el
flag `modules.apps.packetTracer.enable`. El `.deb` del 9.0.0 se sirve
**públicamente** en Archive.org (sin login de NetAcad) y el módulo lo descarga
**solo** en cada rebuild (`fetchurl`): una instalación limpia (clone →
`bootstrap.sh`) construye todo — incl. Packet Tracer — sin tocar nada a mano,
y N máquinas con el mismo repo reconstruyen idénticas. Es unfree
(`allowUnfree` ya está en `modules/core/user.nix`).

Por qué la fuente es `fetchurl` y no `requireFile`: nixpkgs pineó el `.deb` con
`requireFile` (obligaba a bajarlo a mano, política de no-redistribución de
Cisco), pero el archivo está publicado en Archive.org con hash conocido — el
override del módulo solo cambia la fuente. Si Archive.org moviera el item, el
rebuild falla con un fetch: actualizar la URL en
`modules/apps/packettracer.nix` (1 línea).

NO usar el 9.0.1 de NetAcad: su "AppImage" viene en un formato roto (ELF stub +
squashfs sin footer AI + ABI viejas `libjpeg.so.8`/`libtiff.so.5` que nixpkgs
ya no provee) — quedó documentado en el historial del repo si algún día hay que
atacarlo de nuevo.

Verificación (opcional): el `.deb` en Archive.org
(`https://archive.org/download/packettracer900/CiscoPacketTracer_900_Ubuntu_64bit.deb`)
tiene sha256 `dd9ac0d4c7fc37dcb68f627fd7c7e6fa6d4200c14492526e5618b9bd172ed920`
(equivalente flat al hash del módulo).

Gotchas (vistos en la práctica):

- El 9.0.0 de Archive.org y su hash flat coinciden con lo que nixpkgs pineó,
  así que el `fetchurl` del módulo es estable; si Cisco/Cisco-archive mueve o
  re-empaqueta el archivo, el rebuild falla con "hash mismatch" y se actualiza
  el hash en `modules/apps/packettracer.nix` (1 línea, igual que
  `unstableFixesOverlay` en `flake.nix`).
- Las descargas grandes de NetAcad se estancan a mitad (quedan archivos
  `*.deb.part` gigantes en `~/Downloads`): retomar el `.part` o traer el `.deb`
  desde otra máquina por LAN (misma red) es más rápido que reintentar desde cero.

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
- `netrunner` — btop 55% + nvtop 45% (split WezTerm).
- `SecDesk` / `Mirror` (+ `_WiFi <ip>`) — scrcpy tablet mirroring, 85 fps,
  h265/opus, virtual 1920x1080 display for a secure desk setup.
- `ytsong` / `ytlist` — download audio from clipboard (yt-dlp, cookies from Firefox).
- `estabilizar_clips` / `estabilizar_clips_gpu` — re-encode clips to CFR 30
  (CPU x264 or full-VAAPI h264: decode + encode on GPU) for stable editing.
  `estabilizar_clips_gpu` detects HDR10+ clips (ffprobe) and applies libplacebo
  tone-mapping via Vulkan before the VA-API encode.
- `subtitular <video>` — Whisper (whisper.cpp) Spanish subtitles with VAD.
- `spice-find <modelo>` — busca un componente en la librería SPICE (~50k
  modelos de kicad-spice-library) y muestra las variantes con su archivo.
  Equivale al "buscador" de la librería, sin entrar al repo.
- `spice-get <modelo>` — desde la carpeta de un proyecto KiCad, busca y
  extrae el modelo a `localSpice.lib` del proyecto (no duplica). Sanea
  params incompatibles con ngspice (mfg=/type=/SRC=/SYM=) y verifica que el
  modelo carga antes de escribirlo. Equivale al "generador/extractor", en un
  solo comando. Detalles en "KiCad + SPICE".

## Installation on a New Machine

1. Install NixOS with the official installer (any partitioning).
2. `git clone https://github.com/<you>/nixos-config && cd nixos-config`
3. `./bootstrap.sh <host>` — regenerates `hardware-configuration.nix` from the real
   disks, runs `sudo nixos-rebuild --impure switch --flake .#<host>`, and commits the file.

That's it — no manual hardware step, no `gh`/GitHub auth required (the repo is public
and only the local file is touched). On first boot the `yovick` user is created with a
password read from `/etc/nixos-secrets/yovick-password` (created by `./bootstrap.sh`,
never committed; skip it and the user is created without one). Change it after boot
with `passwd`.

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
sudo nixos-rebuild --impure switch --flake .#<host>   # apply system + home changes
home-manager switch --flake .#<host>                  # Home Manager only
nix flake update                              # bump inputs
nix flake check                               # evaluate all hosts
```

## Security Notes

- **Nothing secret is committed**: no SSH keys, no tokens, no credentials, and no
  default password. The initial password lives in `/etc/nixos-secrets/yovick-password`
  (root-only, created by `bootstrap.sh`, never in git).
- The initial password only applies when the `yovick` user is created (first boot) and
  never overrides an existing password.
- **For people cloning this repo:** the config builds the `yovick` user (with a password
  only if you set the secret file); rename the user (`flake.nix`, `modules/core/user.nix`),
  hostname, and `git remote` to your own, then change the password after first login. The
  git identity is **not** hardcoded: it's set per-host via
  `home-manager.users.<you>.modules.apps.git.name` / `.email` (default `null`, so both are
  omitted unless you set them). Only the repo owner (or granted collaborators) can push;
  anyone can clone and fork.
- Rebuilds use `--impure` because `user.nix` reads the local password file at eval time.

## License

- **Source code** (`flake.nix`, `modules/`, `hosts/`, `home/`): [GNU GPLv3](LICENSE-SOFTWARE)
- **Hardware** (`hardware/`): [CERN-OHL-S v2](LICENSE-HARDWARE)
- **Documentation & media** (`docs/`, `assets/`): [CC BY-SA 4.0](LICENSE-MEDIA)
