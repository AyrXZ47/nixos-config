# Migración Wayle → Caelestia: inventario real

Notas verificadas leyendo el código fuente de `caelestia-shell` v2.4.0,
`caelestia-cli` v1.1.2 (ambos de nixpkgs), los dots oficiales
(`caelestia-dots/caelestia`) y la config Wayle actual del repo.

## Arquitectura

| | Wayle (hoy) | Caelestia |
|---|---|---|
| Toolkit | Rust + GTK4 (`gtk4-layer-shell`, `pixman`, `fftw`) | Qt6/QML + Quickshell (SceneGraph GPU) + plugin C++ |
| Config bar/widgets | TOML: `bar` / `styling` / `modules` | `~/.config/caelestia/shell.json` (JSON, plugin `Caelestia.Config`), override per-monitor |
| Config visual | SCSS libre (`wayle/styles/index.scss`) | Tokens: `shell-tokens.json` + JSON. Sin CSS libre |
| CLI | `wayle idle/media/notify` | `caelestia shell/scheme/wallpaper/clipboard/emoji/screenshot/record/toggle ...` |
| Lock | hyprlock (PAM + fprint nativo) | lock propio Quickshell `WlSessionLock` + PAM (`assets/pam.d/*`) |
| Idle | hypridle (solo `lock_cmd`, sin timeouts) | `IdleMonitors.qml` + `general.idle.timeouts` en `shell.json` |
| Wallpaper | mpvpaper (mp4/webm/mkv + `pause=yes` por batería) | `background.Wallpaper` (Quickshell); CLI solo valida imágenes → **mp4 NO soportado** |
| Colores | palette fija cyberpunk | Material You dinámico desde el wallpaper |

## Inventario de la barra Wayle

Barra **derecha** (vertical), `scale=0.85`, `bg=transparent`, botones
`block-prefix`, redondeo `full`, iconos `#ff0066`, botón bg `bg-elevated`.

Grupos y orden:

- `left = [ {top: notifications, clock}, {cava: cava} ]`
- `center = [hyprland-workspaces]`
- `right = [ {system: custom-picker, custom-wallpaper, custom-clipboard},
  {bottom: volume, brightness, battery, bluetooth, network, dashboard} ]`

### Equivalencias

| Wayle | Caelestia | Nota |
|---|---|---|
| `notifications` | entry `statusIcons` + `popouts` + `notifs` | dropdown |
| `clock` (`%I\n%M`, click→calendar) | entry `clock` (`showDate`, `showIcon`) | formato distinto |
| `cava` (44 barras, `peaks`, `mirror`) | `background.visualiser` (barras, blur, autoHide) | **no hay módulo de bar** |
| `hyprland-workspaces` (`label`, `app-icons-show`, `dedupe`, `min=5`) | `bar.workspaces` (shapes/icons, `shown`, `showWindows`, `maxWindowIcons`, `activeIndicator`, `activeTrail`) | rehacer con `windowIcons` regex para `hyprdev` |
| `brightness` (dropdown+OSD, scroll) | `osd.enableBrightness` + `bar.scrollActions.brightness` | OSD cubierto |
| `volume` | `osd` + `bar.scrollActions.volume` | |
| `battery` (`level-icons`, `alert-icon`) | statusIcon `battery` + `general.battery.warnLevels` | más rico |
| `bluetooth` | statusIcon `bluetooth` | |
| `network` (click→dropdown) | statusIcon `network` + `nexus.networkRescanInterval` | |
| `dashboard` (logo, lock/logout/reboot/poweroff) | `dashboard` (media/perf/weather) + `session` (power menu) | **dividir en dos** |
| `custom-picker` (hyprpicker→`wayle notify`) | `caelestia:pickColor` / `SUPER+SHIFT+C` + `notify-send` | |
| `custom-wallpaper` (menu rofi) | launcher `>wallpaper` + `caelestia wallpaper -f` | |
| `custom-clipboard` (rofi+cliphist) | **nativo**: `caelestia clipboard` (fuzzel) + `SUPER+V` | mejora |
| `idle-inhibit` | `utilities.quickToggles` + `IdleInhibitor` | |

### SCSS custom a perder

- `popover.dropdown > contents > .dropdown { margin-right }` → gap barra/dropdown.
- `@keyframes workspace-bounce` (bounce del icono activo) → **no existe**; el
  morphing de Caelestia usa otras animaciones.

## Integraciones fuera de la barra (grep `wayle`)

En `modules/desktop/hyprland.nix`, `hyprland-home.nix`, `modules/apps/shell.nix`,
`modules/apps/vnc.nix`:

1. `hl.exec_cmd("wayle shell")` autostart → `caelestia shell -d`.
2. layer rule `namespace = "wayle"` blur → namespaces Caelestia:
   `caelestia-drawers`, `caelestia-background`, `caelestia-border-exclusion`,
   `caelestia-area-picker`. Caelestia aplica su propio layer rule para
   `caelestia-drawers` vía `Colours.reloadHyprRules()` (usa `hl.layer_rule` en
   Lua).
3. `SUPER+F11/F12` brillo → `brightness.sh` (sigue válido).
4. Media `wayle media play-pause/previous/next` → global shortcuts
   `caelestia:mediaToggle/mediaPrev/mediaNext` (SUPER+F6/F7/F8).
5. `cast-tablet` (vnc.nix) usaba `wayle idle toggle` → `caelestia` no tiene IPC
   de idle; se reemplaza por `hyprctl`/`systemd-inhibit` genérico.
6. README líneas 58-62 y 241.

## Decisión: mpvpaper se queda

El CLI (`utils/wallpaper.py`) solo valida `jpg/jpeg/png/webp/tif/tiff/gif` →
mp4 no es válido como wallpaper de Caelestia. Pero `utils/theme.py`
`apply_colours()` tiene hooks:

- `enableHypr` (default **true**) escribe `~/.config/hypr/scheme/current.lua`.
- `~/.config/caelestia/config.json` acepta `wallpaper.postHook` (recibe
  `WALLPAPER_PATH`, `SCHEME_*`) y `theme.postHook`.
- `~/.config/caelestia/templates/` se procesa con `{{ $primary }}`, `{{ mode }}`.

Plan sin parches:

1. `shell.json`: `background.wallpaperEnabled = false` → Caelestia no pinta fondo.
2. Config del CLI: `theme.enableHypr = false` → Caelestia **no pisa**
   `~/.config/hypr/scheme/current.lua`.
3. `wallpaper.postHook` → `caelestia-wallpaper.sh` que lanza mpvpaper (video) o
   la imagen fija.
4. `~/.config/caelestia/templates/` para la paleta cyberpunk.

Se conserva mpvpaper (con `pause=yes` por batería y `hwdec=vaapi`) **y** el
esquema dinámico de Caelestia para la UI.

## Riesgos

1. **Barra a la IZQUIERDA fija** (`ColumnLayout`; issues #1148/#1749 abiertas,
   sin opción de posición). Decisión del usuario: aceptar de fábrica.
2. **Lock**: `WlSessionLock` + PAM propio. La huella del laptop hoy funciona en
   hyprlock por el trap `fprintAuth=false` (ver README). Caelestia trae
   `assets/pam.d/fprint` con `pam_fprintd.so` → revisar que no pise el setup.
3. **Idle**: `general.idle.timeouts` + `IdleMonitors`. hypridle actual solo
   tiene `lock_cmd`. Decisión del usuario: migrar a Caelestia.
4. **hyprdev**: `app-icons-dedupe` → `bar.workspaces.windowIcons` regex.
5. **Cava de barra** y **bounce SCSS**: sin equivalente (se portan a
   `background.visualiser` o se pierden).
6. **Nix**: `caelestia-shell` 2.4.0 y `caelestia-cli` 1.1.2 ya en nixpkgs (no
   hace falta el flake externo). El CLI escribe config dinámica en
   `~/.config/caelestia/` y `~/.config/hypr/scheme/` en runtime. Los estáticos
   van por `xdg.configFile` de Home Manager.
7. **SDDM/greeter**: Caelestia es Hyprland-only; el lock no sustituye al
   greeter. `sddm-astronaut` se queda.

## Plan por fases

1. `modules/desktop/caelestia.nix`: enable option, paquetes, fonts, OSD,
   session, quickToggles.
2. `shell.json` declarativo: barra izquierda, workspaces, statusIcons,
   dashboard/session, idle, lock.
3. mpvpaper + scheme dinámico via `postHook`.
4. `hyprland-home.nix`: autostart, global shortcuts, layer rules, quitar wayle.
5. `hyprland.nix`: quitar config Wayle, restos, README.
6. PAM lock (fprintd) y validación `nix flake check`.
