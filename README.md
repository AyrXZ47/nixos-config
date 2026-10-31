# NixOS Configuration — Cyberpunk, Modular, Flake-Driven

[![License: GPL v3](https://img.shields.io/badge/Source%20Code-GPLv3-blue.svg)](LICENSE-SOFTWARE)
[![License: CERN-OHL-S](https://img.shields.io/badge/Hardware-CERN--OHL--S%20v2-orange.svg)](LICENSE-HARDWARE)
[![License: CC BY-SA 4.0](https://img.shields.io/badge/Docs%20%26%20Media-CC%20BY--SA%204.0-lightgrey.svg)](LICENSE-MEDIA)

Personal NixOS configuration, 100% declarative and modular. Cyberpunk-themed,
AMD-powered, Hyprland-driven. Same config runs on a VM, a desktop, a laptop and a
headless server — the idea is that whatever works in the VM works identically on
real hardware.

Built on `nixos-unstable` (nixpkgs pinned in `flake.lock`), Nix flakes, Home Manager,
and a hand-rolled cyberpunk theme (magenta `#ed1044` / cyan `#00f0ff` on deep navy).

## Hosts

| Host     | Role      | Hardware                  | GPU          | Tuning                                    |
| -------- | --------- | ------------------------- | ------------ | ----------------------------------------- |
| `pc`     | Desktop   | Ryzen 5700X               | RX 7600      | `amd_pstate=active`, governor `performance` |
| `laptop` | Mobile    | AMD laptop (ThinkPad-ish) | Integrated   | `amd_pstate=active` (común), governor `powersave`, EPP `power`/`performance` y `platform_profile` `low-power`/`performance` según batería/AC |
| `server` | Headless  | AMD                       | (none)       | `amd-common` only, no desktop             |
| `vm`     | Virtual   | QEMU/VMware               | virtio/vmwgfx| virtio initrd, LUKS + btrfs subvols      |

Every host is `x86_64-linux`, runs the CachyOS kernel (`linuxPackages_cachyos`,
7.3.0 with clang thin-LTO and `-O3`, from the `chaotic-nyx` flake), enables the
`yovick` user with
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
│   ├── desktop/       # Hyprland (system + home), Caelestia shell
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
- **Caelestia** — shell Quickshell (Qt6/QML): barra lateral izquierda con
  workspaces, clock, notificaciones, batería, clipboard, emoji, launcher,
  dashboard (media/perf), utilities y menú de sesión. Lock e idle propios: a
  los 30 min de inactividad bloquea (vía `lock.sh`, así corre el wipe de
  cliphist y el perfil RGB) y diez minutos después apaga la pantalla; no
  suspende (el S3 de `pc` aborta al instante, ver
  `modules/hardware/openrgb.nix`). Config
  declarativa en `modules/desktop/caelestia.nix` (`shell.json`).
- polkit-gnome agent, `cliphist` clipboard manager, `hyprshot` screenshots,
  animated wallpapers via **mpvpaper** (looped mp4) driven through Caelestia's
  `wallpaper.postHook` (the shell computes the Material You scheme from the
  video's first frame; mpvpaper keeps painting the real background).

### Pantalla inalámbrica (Miracast) y disposición de monitores
- **Miracast** (`modules/apps/miracast.nix`) — GNOME Network Displays, lo mismo
  que "Windows+K" en Windows: la app pide el screencast al portal y lo manda a
  la TV por Wi-Fi Direct. Necesita dos cosas, y las dos viven en módulos
  compartidos a propósito: `dnsmasq` en el PATH (GND lo invoca por nombre para
  servir DHCP en la interfaz `p2p-dev-*`) y los puertos 67/udp, 123/udp y
  7236/tcp+udp en `modules/core/networking.nix`. Sin cualquiera de las dos el
  link P2P se arma, la TV nunca recibe IP y GND aborta con "connection
  established .. connection lost" — o se queda cinco minutos colgado y cierra
  en silencio. Funcionaba en la laptop y estaba roto en el `pc` porque el fix
  se había quedado en `hosts/laptop` mientras la app la importa
  `home/default.nix` en los 4 hosts. Diagnóstico: `G_MESSAGES_DEBUG=all
  gnome-network-displays > gnd.log 2>&1`.
- **Mirror / Extended** — `SUPER+D` = **Mirror**, `SUPER+SHIFT+D` = **Extended**.
  Los dos son deterministas: ya no alternan, así que no hay que adivinar cuál te
  tocó. `monitor-mirror.sh` tiene tres invariantes: no toca nunca el monitor
  principal (reaplicarle geometría era el bug de "extended falla"), al espejar
  le da al secundario el **mismo timing** del principal (el modo más cercano de
  su propia lista) en vez de `preferred`, porque con timings distintos Hyprland
  muestra cuadros viejos y tearing, y al pasar a Extended reafirma los
  escritorios numerados en el principal. `mirror="none"` es lo que des-espeja;
  `mirror=false` no parsea ("string type requires a string").
- **Escritorios en Extended, estilo GNOME** — `workspace-bind.sh` ata los
  escritorios 1..12 al monitor principal al arrancar y al pasar a Extended. El
  secundario recibe el siguiente número libre (13 en adelante) y queda **vacío**
  hasta que le arrastrás una ventana: no se roba ninguno de los numerados, así
  que `time-to-work` (`SUPER+W`) siempre abre sus escritorios 1-4 en el
  principal. La API Lua **no** mueve un workspace que ya existe en otro monitor
  (`hl.dsp.move_workspace_to_monitor` es nil), por eso el diseño es por orden:
  atar antes de que aparezca el secundario. Si el principal elegido no es el que
  querés (arrancó con el secundario enfocado), enfocá el correcto y volvé a
  correr el script.
- **Brillo** — el único backlight del `pc` es `ddcci8` por DDC/CI: **66 ms por
  write** medidos (10 encadenados = 653 ms, el driver serializa; la lectura es 1
  ms porque el kernel la cachea). Las teclas de brillo ya **no** llevan
  `repeating`: con repeat se encolaban ~15 writes por segundo y el panel quedaba
  segundos atrás. Un toque = un write = 66 ms. Si algún día vuelve a molestar, el
  techo es coalescer (aplicar solo el último valor cada ~80 ms).
- **Por qué Windows se porta mejor espejando** — DWM clona en el pipe de
  display de la GPU con timings que negocia el driver; Hyprland re-renderiza
  cada salida con su propio damage tracking, así que si las dos salidas no
  corren el mismo modo la clonada puede mostrar frames viejos. De ahí el ajuste
  de timing del punto anterior: no es un bug de NixOS ni del kernel.
- **Dark mode** — GTK3/Qt salen de `gtk3/gtk4.extraConfig` y
  `qt.platformTheme`. Las apps GTK4/libadwaita (GNOME Network Displays,
  Nautilus) **ignoran** `gtk-application-prefer-dark-theme`: preguntan el
  esquema al portal, que lo responde leyendo `org.gnome.desktop.interface`.
  Por eso `modules/desktop/hyprland.nix` habilita `programs.dconf` y siembra
  `color-scheme = prefer-dark` en dconf: sin eso la app sale en blanco aunque
  el resto del escritorio esté en oscuro.

### Shell & Terminal
- **Zsh** + Oh My Zsh (`git`, `sudo`) + **powerlevel10k** (instant prompt) +
  autosuggestions + syntax highlighting; word-wise bindings; fzf integration.
- **kitty** — tema cyberpunk vendorizado (MIT), JetBrains Mono Nerd 14px,
  0.66 de opacidad de fondo (vidrio vía Hyprland), cursor trail, símbolos a
  color, splits nativos; `hyprdev`/`netrunner` son ventanas kitty independientes.
- Aliases: `cat→bat`, `du→dust`, `ps→procs`, `top→btop`, `tree→eza --tree`.
- **fastfetch** on terminal open, with the repo logo via kitty image protocol.

### Editor & Dev
- **Neovim** (LazyVim) — tema NeoCyberVim, smear-cursor, render-markdown,
  obsidian.nvim (`~/Sync/Notes`), mason, rainbow-delimiters,
  treesitter-context, lsp_lines; multicursor.nvim
  (`<leader>mj`/`<leader>mk` añaden cursor abajo/arriba, `<leader>mn` al siguiente
  match, Ctrl+click, `<Esc>` cierra); LSPs: lua-language-server,
  stylua, typescript-language-server, pyright, gcc.
- **OpenCode v2 + DeepSeek V4.1 Flash** — agente por defecto (ver "AI stack" abajo).
- **Pi pelado** — harness de respaldo, sin gentle-ai ni paquetes.
- **Ollama** (local AI stack, `OLLAMA_API_BASE` set).
- **Ollama version pin** (`modules/apps/ollama-bin.nix`, solo pc): instala el
  binario oficial v0.32.12 desde los tarballs de la release (base + addon ROCm)
  porque nixpkgs-unstable va con días de retraso y modelos nuevos (ej. qwen3.8)
  exigen releases recientes. Laptop sigue con `ollama-vulkan` de nixpkgs. Para
  subir de versión: cambiar `version` y los dos `sha256` en el módulo (hashes del
  API de GitHub).

### AI stack (OpenCode + Pi pelado)

- **OpenCode v2** (`pkgs.opencode`) es el harness por defecto. `hyprdev` lo
  lanza con `--auto`; la config vive en `~/.config/opencode/opencode.json` y
  `~/.config/opencode/cli.json`, sembrada por `modules/apps/opencode.nix` con
  merge idempotente (OpenCode reescribe esos archivos).
- **Modelo único**: `opencode-go/deepseek-v4.1-flash` con variante `max` para
  todas las sesiones. El root `model` acepta `{ providerID, model, variant }`;
  no hace falta tocar cada agente.
- **Notificaciones**: `cli.json` prende `attention.notifications`, `sound`,
  `sound_pack` y `volume: 1`, con un WAV generado en build para `done` y
  `subagent_done`; `common-packages.nix` crea `/usr/bin/pw-play` para que el
  audio no dependa del PATH.
- **Skills globales**: `security-audit` (Cloudflare), `ponytail` y
  `frontend-design` (Anthropic) se bajan de upstream con `fetchFromGitHub` en
  `modules/apps/opencode-skills.nix` y se enlazan en
  `~/.config/opencode/skills/`. Se actualizan cambiando el `rev` y el `hash`;
  no se clonan en cada repo. También instala los comandos `/ponytail*`.
- **MCPs livianos**: `context7` (docs de librerías) y `gh_grep` (búsqueda de
  código en GitHub) por HTTP, sin proceso local; `duckduckgo` local vía `uvx`
  para búsqueda web y fetch sin API key ni costo. `websearch` nativo queda
  apagado para no pedir un proveedor pago.
- **Pi pelado**: se instala `pkgs.pi-coding-agent` y nada más. `pi.nix` borra
  paquetes, extensions, agentes, chains, MCPs y restos de gentle-ai en cada
  switch; solo conserva `auth.json`, sesiones y el modelo por defecto.
- **Memoria**: Basic Memory con proyecto `memoria` apuntando a
  `~/Sync/Notes/PC & AI/Memory`. Las notas Markdown viajan por Syncthing a la
  laptop; el índice SQLite queda local en `~/.basic-memory`. Se instala y
  configura solo en el rebuild, no usa Ollama ni API key. La carpeta es
  dedicada para no indexar todo el vault ni agregar frontmatter a notas ajenas.
  El activation resuelve `$HOME` en cada host porque Basic Memory no expande
  `~` dentro de `config.json`; no se hardcodea `/home/yovick`.
- **Archivos**: OpenCode lee texto/CSV/imágenes nativo; para PDF se usa
  `pdf2md` (ya instalado en `common-packages.nix`) y se lee el Markdown.
- **`hyprdev`**: la ventana invocadora ejecuta `opencode --auto`; las otras
  tres siguen siendo nvim, shell libre y pipes-rs.

### Gaming
- **Steam** (gamescope session, Remote Play + dedicated server + LAN transfers
  firewalls, protontricks) with **Proton GE**.
- **GameMode**, **MangoHud**, **Gamescope**, **ProtonUp-Qt**, Wine (Wayland),
  Winetricks.
- **Mandos PS4 (clones) por Bluetooth** (`modules/desktop/hyprland.nix` +
  `modules/apps/gaming.nix`): los clones de DS4 emparejan SIN bonding
  (`Bonded: no` en `bluetoothctl info`) y el plugin input de bluez >= 5.69
  rechaza su conexión HID (`Rejected connection from !bonded device`) a menos
  que `hardware.bluetooth.input.General.ClassicBondedOnly = false`. Trampa
  triple: la opción vive en `input.conf` (NO en `main.conf`), sección
  `[General]` (NO `[Input]` — bluez falla en silencio y queda el default
  `true`), y `bluetoothd` NO recarga config en `switch` (reiniciar a mano:
  `sudo systemctl restart bluetooth`). Emparejar por CLI con agente:
  `bluetoothctl` → `agent on` → `scan on` → (SHARE+PS en el mando) →
  `pair <MAC>` → confirmar → `trust <MAC>` → `connect <MAC>`. Tras el primer
  pair+trust, reconectar es solo presionar PS.

### Toolchains (system-wide)
- **Android**: `android-tools` (adb/fastboot).
- **Arduino**: `arduino-cli`.
- **Embedded (ESP32 / STM32)**: `esptool`, `stm32flash`, `openocd` (debug/flash).
- **Raspberry Pi**: `rpiboot` (mass-storage boot), `raspberrypi-eeprom`,
  `picocom` (serial console).
- **Rust**: `rustup` (toolchains on demand). **JS**: `pnpm`.

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

Simulador de redes de Cisco (Cisco Networking Academy). Definición
**vendorizada** en `modules/apps/packettracer.nix` (copia de la de nixpkgs
**9.0.0**, AppImage estándar que `appimageTools` empaqueta sin hacks),
**activo en los hosts gráficos** (pc/laptop/vm) con el
flag `modules.apps.packetTracer.enable`. El `.deb` del 9.0.0 se sirve
**públicamente** en Archive.org (sin login de NetAcad) y el módulo lo descarga
**solo** en cada rebuild (`fetchurl`): una instalación limpia (clone →
`bootstrap.sh`) construye todo — incl. Packet Tracer — sin tocar nada a mano,
y N máquinas con el mismo repo reconstruyen idénticas. Es unfree
(`allowUnfree` ya está en `modules/core/user.nix`).

Por qué vendorizada y con `fetchurl` y no el paquete de nixpkgs: nixpkgs avanza
al ritmo de Cisco (el bump de 2026-09-16 lo pasó a 9.0.1, que viene roto) y lo
pinea con `requireFile` (bajarlo a mano, política de no-redistribución de
Cisco). El módulo fija el 9.0.0 y cambia la fuente al `fetchurl` de Archive.org
(hash conocido). Si Archive.org moviera el item, el rebuild falla con un fetch:
actualizar la URL/hash en `modules/apps/packettracer.nix` (1 línea).

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
- Obsidian va píneado a `electron_42` en `home/default.nix`: con el electron que
  resuelve nixpkgs (43.x) el renderer tira `webFrame ... undefined` y la ventana
  queda gris. Si un bump de nixpkgs lo arregla, se saca el override.

## Performance & Tuning

### Nix daemon (`modules/core/nix-optimization.nix`)
- `cores = 0`, `max-jobs = auto` — uses every core/thread.
- CPU/IO scheduler `idle` while building → no freezes on the desktop.
- Substituters: `cache.nixos.org` + `hyprland.cachix.org` (avoids compiling Hyprland).
- No automatic GC/upgrade (removed 2026-10-21): the four `Persistent=true`
  timers (`nix.gc`, `trim-generations`, `nix.optimise`, `system.autoUpgrade`)
  all caught up at the first boot of the day and burned 9-10 min of store GC
  plus a no-op rebuild competing with the login session. Cleanup is manual now
  — see [Day-to-Day](#day-to-day).

### Hardware (`modules/hardware/`)
- Kernel: `linuxPackages_cachyos` (flake input `chaotic` → overlay + cache
  `nyx-cache.chaotic.cx`) in every host. nixpkgs has no CachyOS kernel, and zen
  is `-O2` without LTO. It ships 7.3.0 as clang thin-LTO `-O3`, `PREEMPT` full,
  HZ 1000, hugepages `always` and sched_ext. The `chaotic` input deliberately
  does **not** follow `nixpkgs`: nyx builds the kernel against its own pin, and
  that pin is what its binary cache holds. `deploy` passes the nyx substituter
  on the command line so the first switch substitutes instead of compiling.
- AMD microcode, `hardware.graphics` 32-bit.
- `zramSwap` at 50% memory.
- `quiet` is declared once, in `nix-optimization.nix`, for every host;
  `splash` lo agrega el módulo de plymouth en los hosts que lo tienen, y
  `loglevel=0` was removed so a live freeze still shows on console.
- Common kernel params: `split_lock_detect=off`. The NMI watchdog is deliberately
  left ON — with it off a whole-system freeze leaves no trace at all.
- Desktop: `amd_pstate=active`, `mitigations=off`, `max_cstate=1`, `performance`
  governor, `scx_lavd --performance` (sched_ext, userspace), `MESA_SHADER_CACHE_MAX_SIZE=8G`.
- Laptop: `powersave` governor + EPP `power` en batería y `performance` en AC,
  `platform_profile` `low-power`/`performance` por el mismo script, `scx_lavd
  --powersave`, sin `max_cstate=1`, touchpad libinput (clickfinger, natural
  scrolling), iio sensors, NetworkManager con wpa_supplicant.
- Root en `pc`/`laptop`: btrfs montado con `discard=async` (`modules/core/btrfs.nix`),
  TRIM continuo sin timer `fstrim`.
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
- **Lock de Caelestia** (bloqueo de pantalla) — el shell trae su propia unidad
  PAM (`assets/pam.d/fprint` → `pam_fprintd.so`, `lock.enableFprint = true` en
  `shell.json`); no pasa por `/etc/pam.d`.
- **NO** en SDDM: no tiene UI de huella y `pam_fprintd` bloqueaba el login
  esperando el dedo; el PAM de `login`/`sddm` está desactivado a propósito
  (`fprintAuth = false`).
- PC sin sensor: no pasa nada, todo sigue por contraseña (fprintd no encuentra
  dispositivos y `pam_fprintd` falla rápido).

> Nota: `security.pam.services.<name>.fprintAuth` **defaulta a `true`** cuando
> `services.fprintd.enable` está activo, así que todos los servicios PAM la
> heredan salvo que se apague explícitamente.

Al **volver de suspender** (suspend manual desde el menú de sesión, o al cerrar
la tapa en `laptop`) el xHCI Renesas resetea el bus y el sensor reenumera con
firmware `0.00`; libfprint lo ignora
(`unsupported firmware version`) y fprintd deja la reserva colgada, así que sudo
deja de pedir la huella. `fingerprint.nix` lo recupera solo con
`powerManagement.resumeCommands` (rebind del USB + `systemctl restart fprintd`).
Si pasa en vivo sin querer esperar al reboot: `sudo systemctl restart fprintd` y,
si sigue, rebind del USB o reboot.

Además, el **lock de Caelestia** ya estaba `secure` antes de dormir, así que al
despertar no vuelve a montar el `pam_fprintd` (muerto con el suspend) y el lock
quedaba sin huella hasta el siguiente bloqueo. El flake parchea
`modules/lock/Pam.qml` para que `onResumed` reinicie el fprint y sondee la
disponibilidad hasta que el sensor reenumere (~30 s).

### Boot
- **systemd-boot** on every host; `boot.initrd.systemd` + Plymouth (`ironman`
  theme from `adi1090x-plymouth-themes`); quiet boot.
- `fwupd` does not start at boot (it cost 38.9s on the laptop): the unit is
  dbus-activatable, so `fwupdmgr` starts it on demand.
- PipeWire (ALSA/Pulse/JACK) + rtkit for pro audio; ZRAM swap.

## Keybindings (Hyprland)

| Keys | Action |
| ---- | ------ |
| `SUPER Backspace` | Terminal (kitty) |
| `SUPER Delete` | Kill window |
| `SUPER V` | Toggle floating |
| `SUPER J` | Toggle split |
| `SUPER arrows` / `SUPER SHIFT arrows` | Focus / move window |
| `SUPER 1-9` / `SUPER SHIFT 1-9` | Switch / move to workspace |
| `SUPER ALT SHIFT 1-9` | Move ALL windows of active ws to N and follow (GNOME-style) |
| `SUPER W` | *time-to-work*: Mixxx → Obsidian → Firefox → kitty on ws 1-4 |
| `SUPER N` | *netrunner*: btop + nvtop (2 ventanas kitty) |
| `SUPER SPACE` | Switch keyboard layout (latam/us) |
| `SUPER L` | Lock session (Caelestia lock + hooks OpenRGB/cliphist) |
| `SUPER P` variants | Screenshot region (`SUPER SHIFT P`) / window (`SUPER ALT P`) / screen (`SUPER P`) |
| `SUPER CTRL SPACE` | Caelestia launcher |
| `SUPER CTRL D` / `SUPER CTRL Q` | Caelestia dashboard / session menu |
| `SUPER CTRL U` / `SUPER CTRL N` | Caelestia utilities panel / sidebar |
| `SUPER CTRL K` | Caelestia show-all (launcher + dashboard + OSD) |
| `SUPER SHIFT V` / `SUPER Period` | Clipboard history / emoji picker (Caelestia) |
| `SUPER F6/F7/F8` | Media prev / play-pause / next (Caelestia MPRIS) |
| `SUPER D` / `SUPER SHIFT D` | Mirror / Extended (deterministas, no alternan) |
| Media keys | Volume (wpctl), mic mute, brightness (brightnessctl) |

## Custom Commands

- `hyprdev [repo]` — workspace dev en 4 ventanas kitty independientes
  (OpenCode, nvim, shell libre, pipes-rs); el directorio opcional entra al repo
  antes de abrir todo. Cierre en cadena: si cae una ventana, se cierran las demás.
- `opencode-pair [puerto]` — bindea el servicio de OpenCode a la IP de Tailscale,
  lo reinicia y muestra el QR para abrir la sesión desde el navegador del
  celular. Sin Tailscale, usar `opencode pair --remote --yes`.
- `netrunner` — btop + nvtop en 2 ventanas kitty (nvtop al lado, cierre en cadena).
- `SecDesk` / `Mirror` (+ `_WiFi <ip>`) — scrcpy tablet mirroring, 85 fps,
  h265/opus, virtual 1920x1080 display for a secure desk setup.
- `ytsong` / `ytlist` — download audio from clipboard (yt-dlp, cookies from Firefox).
- `estabilizar_clips` / `estabilizar_clips_gpu` — re-encode clips to CFR 30
  (CPU x264, or h264_vaapi encode on GPU) for stable editing. `_gpu` accepts
  mp4/mov/mkv, applies the clip's own rotation, and re-encodes non-AAC audio to
  AAC. Only the ENCODE runs on the GPU: on radeonsi the VA-API h264 decoder
  only allocates surfaces for aligned widths (720p works, 576/832 do not), so
  decoding stays in RAM and frames are uploaded with `hwupload`. HDR10/HLG
  clips are tone-mapped on the CPU (`zscale`+`tonemap`): this ffmpeg ships
  without libplacebo and radeonsi's VPP has no HDR support, so neither
  `libplacebo` nor `tonemap_vaapi` is usable here.
- `subtitular <video>` — Whisper (whisper.cpp) Spanish subtitles with VAD.
- `narravoz <guion.md|txt> [voz]` — text to speech with Microsoft's neural
  voices via `edge-tts` (the Edge/Azure ones), default `es-MX-DaliaNeural`.
  A two-minute script takes about 3 s. The text is sent to Microsoft, so it is
  not suitable for confidential material; nixpkgs pins 7.2.8, which returns
  403 because Microsoft rotates its `Sec-MS-GEC` token, so
  `modules/apps/tts.nix` overrides it to 7.3.1.
- `pdf2md <pdf>...` — PDF to Markdown, meant for feeding documents to an LLM
  as context. A PDF cannot be read raw (its content streams are compressed),
  so it extracts the text layer with pymupdf on CPU — no OCR, no models, ~0.5 s
  for 13 pages — and rebuilds the structure from the page geometry: headings
  from font size/bold, and the line breaks the PDF inserts mid-sentence joined
  back into paragraphs. Writes `<name>.md` next to each PDF (`-o <file>` for a
  single destination, `-o -` for stdout). A scan with no text layer is refused
  with a non-zero exit instead of writing a Markdown full of holes: silently
  partial context is worse than none. It deliberately avoids `pymupdf4llm`,
  whose list detection turns a wrapped line starting with `o ` into a bullet
  and eats the letter.
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

**rtk** sigue el mismo patrón de opencode (release prebuilt, tarball commiteado
`nix-on-droid/rtk-0.48.0-aarch64.tar.gz`, 4 MB): el paquete no existe en nixpkgs
25.11 y el de unstable no corre bajo este proot (glibc ≥2.42). La activación lo
extrae a `~/.local/bin` (ya en sessionPath por `shell.nix`) con `patchelf` al
interpreter de glibc del store + rpath a libgcc (enlaza `libgcc_s.so.1`; su
símbolo glibc más alto es 2.39, cabe en el 2.40 del pin). Verificar el checksum
contra `checksums.txt` del release al reemplazarlo. Una vez en el celular:
`rtk init -g --opencode` instala el plugin de opencode (archivo TS en
`~/.config/opencode/plugins/`, no declarativo).

**Gotchas del entorno proot** (por qué algunas cosas del PC no van aquí):
- `btop` no: proot falsifica `/proc/stat` con un stub mínimo que solo soporta `htop`.
- `fastfetch` corre con su config por defecto (la del PC usa logo PNG y líneas anchas).
- `hyprdev`/`netrunner` requieren kitty + Hyprland — no existen en Android (usa la terminal de la app).
- `ping` funciona solo si el SELinux del fabricante permite raw sockets.
- El env default de nix-on-droid no trae ni `grep`: el flake añade gnugrep, gnused,
  gnutar, gzip, bzip2, xz, zip, findutils, diffutils, procps, killall.

## Day-to-Day

```bash
sudo nixos-rebuild --impure switch --flake .#<host>   # apply system + home changes
home-manager switch --flake .#<host>                  # Home Manager only
deploy <host>                                         # lo mismo, desde cualquier máquina (local o por ssh -t)
nix flake update                              # bump inputs
nix flake check                               # evaluate all hosts
```

No cleanup timers run in background any more (see Performance & Tuning). When a
host needs maintenance, run this by hand:

```bash
sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +6  # keep 6
sudo nix-collect-garbage                                             # free store
sudo nix-store --optimise                                            # dedup store
```

`nix-collect-garbage -d` is NOT the same thing: `--delete-old` drops *every* old
generation (no rollback left). Use it only when you mean it.

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

### Endurecimiento base (`modules/core/hardening.nix`)

Se importa desde `mkHost`, así que aplica a los 4 hosts:

- **sysctl sin costo medible**: `kptr_restrict=2`, `kexec_load_disabled=1`,
  `suid_dumpable=0`, SIN reenvío de ICMP redirects, `tcp_rfc1337=1`.
  NixOS ya trae `randomize_va_space`, `ptrace_scope`, `dmesg_restrict`,
  `unprivileged_bpf_disabled`, `protected_*` y `tcp_syncookies`.
- **sshd acotado**: sin login de root, solo `yovick`, `MaxAuthTries=3`,
  `LoginGraceTime=30s`. El puerto 22 **no** está abierto al mundo: el firewall
  lo deja cerrado salvo en `tailscale0` (`trustedInterfaces`), así que el SSH
  solo se llega por la tailnet.
- **Contraseña SSH aún habilitada a propósito**: no hay `authorized_keys` en
  ningún host. Antes de apagarla, instalar la pubkey y probar
  `ssh -o PasswordAuthentication=no` desde otro nodo de la tailnet.
- **sudo solo para `wheel`** (`execWheelOnly`); `wheelNeedsPassword` sigue en
  `true`.

**Lo que NO se habilita, a propósito:** SELinux y AppArmor. NixOS no trae
perfiles de AppArmor cargados por defecto: activar el LSM sin escribir perfiles
por app no protege nada y sí puede romper GPU/IA/juegos. El aislamiento real de
este setup es el *sandboxing de systemd* que ya aplican los módulos de nixpkgs
(`ProtectSystem`, `ProtectHome`, `PrivateTmp`, `NoNewPrivileges`, etc.). Si algún
día se quiere MAC de verdad, el orden es: perfiles de AppArmor para los daemons
expuestos (primero), no el flag suelto.

**Rendimiento vs. seguridad:** endurecimientos que cuestan CPU (`init_on_alloc`,
`slab_nomerge`, `page_alloc.shuffle`, mitigaciones de CPU) quedan fuera porque
este repo prioriza rendimiento. El costo de cada uno se paga en cada `malloc`
o en cada llamada al sistema — se pueden probar uno por uno con
`nixos-rebuild test` si en algún momento se prefiere el otro lado.


## License

- **Source code** (`flake.nix`, `modules/`, `hosts/`, `home/`): [GNU GPLv3](LICENSE-SOFTWARE)
- **Hardware** (`hardware/`): [CERN-OHL-S v2](LICENSE-HARDWARE)
- **Documentation & media** (`docs/`, `assets/`): [CC BY-SA 4.0](LICENSE-MEDIA)
