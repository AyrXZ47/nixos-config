# Auditoría — Ola 9 (UPS/nobreak como batería, watts, netrunner en cadena, emoji kitty)

- **Árbol auditado**: `main` @ `06fef1f` (integrado; merges `8aea7bf`, `e25a401`,
  `98d32e4`, `06fef1f`).
- **Base de la ola**: `2103047` (`docs: planificar ola 9`).
- **Fecha**: 2026-09-20 22:03 CST.
- **Alcance**: 4 ejecutores, archivos disjuntos.
- **Veredicto**: **APPROVED WITH EXCEPTIONS** (excepciones no bloqueantes, §7).

Evidencia > narración: cada check es un comando ejecutado por el auditor sobre el
árbol integrado; se transcribe la salida.

---

## 1. Integridad de integración

- `git status --porcelain` → vacío (0 líneas). `git stash list` → vacío.
- `HEAD = 06fef1f merge: wave 9 wave9-executor-4`; los 4 merges presentes.
- La ola 9 tocó **exactamente** el mapa de propiedad:

  ```
  $ git diff --name-status 2103047..HEAD
  M  flake.nix
  M  modules/apps/kitty.nix
  M  modules/apps/shell.nix
  M  modules/desktop/caelestia.nix

  $ git diff --stat 2103047..HEAD
   flake.nix                     | 48 +++++++++++++++++++++++++++++++++++++++++++
   modules/apps/kitty.nix        |  5 +++--
   modules/apps/shell.nix        | 41 ++++++++++++++++++++++++++++++++++--
   modules/desktop/caelestia.nix | 15 +++-----------
   4 files changed, 93 insertions(+), 16 deletions(-)
  ```

  Mapa: `flake.nix` → E1; `caelestia.nix` → E2; `shell.nix` → E3;
  `kitty.nix` → E4. Sin invasiones de territorio.
- `git log --stat` por rama: cada ejecutor tocó **solo** su archivo
  (`wave9-executor-1` → flake.nix; `-2` → caelestia.nix con 2 commits, permitido
  por el brief; `-3` → shell.nix; `-4` → kitty.nix).
- `flake.lock` **intacto**: `git diff 2103047..HEAD -- flake.lock` → 0 líneas.
  Sin dependencias nuevas.
- Branch isolation OK: `git ls-remote --heads origin` contiene
  `wave9-executor-1 f129aa3`, `-2 cb6cfe7`, `-3 8a50ab3`, `-4 f9bdeb9`, todos
  iguales a las ramas locales; `origin/main 06fef1f` = local.
- Commits no-merge en conventional-commit español, una línea:

  ```
  f129aa3 feat(caelestia): tratar UPS como bateria y mostrar watts
  f9bdeb9 fix(kitty): ampliar symbol_map al bloque U+2B00-U+2BFF
  cb6cfe7 chore(caelestia): limpiar entradas muertas de windowIcons
  8a50ab3 feat(shell): cierre en cadena para netrunner
  3a4b196 fix(caelestia): quitar workspaceIcons inválido del seed
  ```

## 2. Build & tests

| Check | Comando | Resultado |
|-------|---------|-----------|
| Flake check (todos los hosts) | `nix flake check` | `all checks passed!` · EXIT=0 |
| Toplevel pc | `nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel` | EXIT=0 (sin salida) |
| Verify E1 | build de `caelestia-shell` + greps `UPowerDeviceType.Ups` / `changeRate` | PASS |
| Verify E2 | `shellJsonPath` sin `workspaceIcons`, con `windowIcons` | PASS |
| Verify E3 | `zsh.initContent` con `netrunner-nvtop` y `netrunner-watch`, sin `--cwd` | PASS |
| Verify E4 | `kitty.settings.symbol_map` contiene `U+2B00` | PASS |
| Sintaxis zsh | `zsh -n` sobre `initContent` (393 líneas) | OK |

### Verify E1 — QML del overlay UPS (árbol integrado)

```
$ out=/nix/store/wmzxws66p4w5akf1l5bq1ccb2lbqc5dk-caelestia-shell-2.4.0
$ grep UPowerDeviceType.Ups .../dashboard/Performance.qml          → 2 usos (l.20, l.136)
$ grep UPowerDeviceType.Ups .../bar/components/status/BatteryStatus.qml → 1 uso (l.12)
$ grep UPowerDeviceType.Ups .../bar/popouts/Battery.qml            → 2 usos (l.16, l.36)
$ grep UPowerDeviceType.Ups .../lock/Fetch.qml                     → 1 uso (l.93, const hasBatt)
$ grep changeRate .../dashboard/performance/BatteryTank.qml        → l.141-142 (StyledText W)
E1 VERIFY: PASS
```

`BatteryTank.qml` construido, bloque nuevo correcto e indentado:

```qml
            StyledText {
                visible: Math.abs(UPower.displayDevice.changeRate) > 0.05
                text: `${Math.abs(UPower.displayDevice.changeRate).toFixed(1)} W`
                color: contents.subTextColour
                font: Tokens.font.body.small
            }

            StyledText {
                text: `${Math.round(UPower.displayDevice.percentage * 100)}%`
                ...
```

### Verify E2 — seed `shell.json`

```
$ j=$(nix eval --raw .#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath)
  → /nix/store/h764yzvq6rrkjira2yi1j5kym8g74ycv-caelestia-shell.json
$ grep -c workspaceIcons "$j"  → 0  (NOT FOUND, good)
$ grep -c windowIcons    "$j"  → 1  (FOUND, good; solo la entrada `steam`)
E2 VERIFY: PASS
```

El seed conserva `windowIcons` con la única entrada `steam`; las entradas muertas
`hyprdev.*` y wezterm fueron eliminadas (tarea opcional de E2, dentro de su
archivo).

### Verify E3 — `netrunner` con cierre en cadena

```
$ c=$(nix eval --raw '...programs.zsh.initContent')
  netrunner-nvtop: yes
  netrunner-watch: yes
  --cwd: absent (good)
E3 VERIFY: PASS
$ printf '%s' "$c" > /tmp/initContent.zsh && zsh -n /tmp/initContent.zsh → ZSH SINTAXIS: OK
```

El watcher replica el patrón ya auditado de `hyprdev` (2 ventanas: address de la
invocadora + título `netrunner-nvtop`; `kill` por PID del pidfile, nunca
`closewindow`; timeout de arranque ~30 s). `hyprdev()` no fue alterado.

### Verify E4 — `symbol_map`

```
$ nix eval --raw '...programs.kitty.settings.symbol_map' | grep U+2B00
U+1F300-U+1FAFF,U+2600-U+27BF,U+2190-U+21FF,U+2B00-U+2BFF Noto Color Emoji
E4 VERIFY: PASS
```

### Smoke test de carga de la shell (obligatorio: la ola toca QML)

El proceso vivo de quickshell apunta exactamente al store construido por la ola
(`wmzxws66…-caelestia-shell-2.4.0`), así que el smoke test prueba el QML
**parcheado**, no uno viejo:

```
$ pgrep -af 'caelestia[-]shell'
231713 /nix/store/gvgrz4bh…-quickshell-0.3.1/bin/quickshell \
  -p /nix/store/wmzxws66p4w5akf1l5bq1ccb2lbqc5dk-caelestia-shell-2.4.0/share/caelestia-shell -n -d

$ pkill -f 'caelestia[-]shell'; sleep 1
$ caelestia shell -d 2>&1 | tee /tmp/qs-start.log
  INFO: Launching config: ".../wmzxws66…-caelestia-shell-2.4.0/share/caelestia-shell/shell.qml"
  INFO: Shell ID: "694ab250…"
  INFO: Saving logs to "/run/user/1000/quickshell/by-id/hsy4qi4plt/log.qslog"
  WARN caelestia.settings: Unknown option "bar.workspaces.workspaceIcons"
  INFO: Configuration Loaded
$ ! grep -qi 'Failed to load configuration' /tmp/qs-start.log
SMOKE: PASS  (shell arranca y responde; proceso 231713 vivo)
```

Los únicos WARN/ERROR en `log.qslog` son **preexistentes y ajenos a la ola**
(`PowerProfilesDaemon` no disponible, registro de portal D-Bus); **no hay**
`ReferenceError`/`TypeError`/binding inválido de los parches nuevos. Además el log
confirma que Quickshell clasifica el nobreak como UPS:

```
… /org/freedesktop/UPower/devices/ups_hiddev2/…Device:Type to
   qs::service::upower::UPowerDeviceType::Ups
```

Entorno (evidencia de la ola): `upower -e` → `ups_hiddev2` (CPS LX1100G3,
`state: fully-charged`, `percentage: 100%`, `time to empty 1.5 h`); sin
`energy-rate` porque está cargado (0 W) → el `StyledText` de watts queda oculto,
como diseñó el plan.

## 3. Disciplina ponytail

- Sin dependencias nuevas (`flake.lock` intacto); sin archivos nuevos; diffs
  mínimos por tarea (+48, +3/-2, +39/-2, +3/-11).
- Reutiliza patrones existentes: `substituteInPlace --replace-fail` del overlay,
  watcher/pidfile de `hyprdev()` copiado sin abstraer, `windowIcons` recortado en
  lugar de añadir lógica.
- No se pidió ni se introdujo helper QML nuevo; no se tocó `quickshell` (C++).
- `ponytail:` no aparece en esta ola; no hay atajos nuevos con techo conocido
  (el watcher por polling hereda el patrón de `hyprdev`, ya auditado). No
  bloqueante.

## 4. Seguridad

- `git diff 2103047..HEAD | grep -iE 'api.?key|secret|token|password|PRIVATE KEY'`
  → único match `Tokens.font.*` (falso positivo QML). Sin secretos.
- `git ls-files | grep -iE '\.env|credential|secret|\.pem|id_rsa'` → nada.
- Sin assets ni licencias nuevas; no se distribuye → release gate
  (`skills/security-audit`) **no aplica**.
- Inputs: el único dato externo es `$1` (directorio) en `netrunner()`, citado
  (`-d "$dir"`). Los pidfiles en `/tmp` usan `runid` timestamp+$RANDOM, igual que
  `hyprdev` (patrón previo). Sin superficie nueva relevante.

## 5. Findings informativos (H)

- **H1 (ola 8) — parcialmente cerrado.** El seed ya no contiene
  `workspaceIcons`, pero el **shell.json vivo del usuario** sí, y el smoke test
  lo demuestra: sigue apareciendo `WARN caelestia.settings: Unknown option
  "bar.workspaces.workspaceIcons"` en cada arranque.

  ```
  $ grep -c workspaceIcons /nix/store/h764…-caelestia-shell.json   → 0   (seed OK)
  $ python3 -c "…" ~/.config/caelestia/shell.json
    workspaceIcons: []
  ```

  El activation `caelestiaSeedConfig` **respeta** un `shell.json` real (editado
  por Nexus) y solo copia el default si **no existe**
  (`modules/desktop/caelestia.nix:708-722`). Por eso el WARN no desaparece en la
  sesión viva. El paso del humano en el plan (rebuild + restart) **no** lo
  elimina. → Excepción E1.
- **H2 — entradas `windowIcons` muertas persisten en el shell.json vivo**
  (`hyprdev.*`, wezterm). Inofensivo: esas clases ya no existen (las ventanas son
  `kitty`). Se limpia solo al re-sembrar el archivo. Informativo.
- **H3 — verify E3 más fuerte que el de la ola 8.** `netrunner-watch` aparece
  solo en código (no en comentario); `netrunner-nvtop` aparece también en un
  comentario, pero el grep combinado con `netrunner-watch` lo hace significativo.
- **H4 — worktrees de la ola 9 no retirados** (patrón histórico de olas
  2/8; `git worktree list` muestra los 4). Operativo, no bloqueante.
- **H5 — checklists** (`audit-checklist.md`) ya usa `caelestia[-]shell` (H3 de la
  ola 8 lo arregló el planner en `2103047`). Cerrado.

## 6. Validación en vivo pendiente (no ejecutable por el auditor)

| Qué | Por qué no lo puede hacer el auditor | Cómo lo valida V |
|-----|--------------------------------------|------------------|
| UPS como batería en el dashboard | Requiere mirar el panel performance de la sesión viva | Abrir el dashboard: el CPS LX1100G3 debe salir como batería con `%` |
| Watts al descargar | Hoy `EnergyRate=0` (cargado); no hay dato | Desconectar el nobreak/AC y ver `${…} W` junto al `%` (si el UPS reporta `EnergyRate`) |
| Emoji de kitty (`U+2B50` estrella de p10k) | Es del prompt interactivo | Abrir kitty nuevo y ver la estrella del prompt a color |
| Cierre en cadena de `netrunner` | `netrunner` hace `exec btop` sobre la ventana **activa**; ejecutarlo desde el kitty del auditor secuestraría la sesión de auditoría | Desde kitty: `netrunner` → 2 ventanas (btop + nvtop al lado); cerrar una debe cerrar la otra |

> El auditor ya reinició la shell una vez (smoke test). El warning H1 seguirá
> apareciendo hasta que V borre `~/.config/caelestia/shell.json` y deje que el
> activation/`caelestia-restart.sh` lo re-siembre.

## 7. Excepciones (con owner)

| # | Excepción | Owner | Estado |
|---|-----------|-------|--------|
| E1 | H1: el WARN de `workspaceIcons` persiste en la sesión viva porque el `shell.json` real del usuario no se sobreescribe; requiere borrarlo y re-sembrar | V (+ planner para documentarlo en el plan) | no bloqueante; el seed está corregido |
| E2 | Validación visual/funcional en vivo (UPS, watts al descargar, emoji del prompt, cierre en cadena de `netrunner`) | V | pendiente; no ejecutable por el auditor sin secuestrar su sesión |
| E3 | Worktrees de la ola sin retirar (H4) | operativo | informativo |

## Veredicto

**APPROVED WITH EXCEPTIONS.** Integración limpia (solo los 4 archivos del mapa,
`flake.lock` intacto), `nix flake check` + toplevel de `pc` pasan, los 4 verify
pasan sobre el árbol integrado, y el **smoke test de carga de la shell pasa**: el
QML parcheado (store `wmzxws66…`) carga sin errores de binding y lo único que
estorba es el WARN de un `shell.json` vivo que quedó stale. Las excepciones son
la validación en vivo de V y ese residuo de estado de usuario, ninguno funcional
del código de la ola.

## Handoff (para el planner)

- Registrar en el decision log: ola 9 auditada **APPROVED WITH EXCEPTIONS**.
- Añadir al plan el paso que falta para cerrar H1 de verdad: borrar
  `~/.config/caelestia/shell.json` (el activation solo re-siembra si **no
  existe**) y reiniciar la shell. Sin eso, el WARN sigue en cada arranque.
- Endurecer el verify de E1 de la ola 8 (`shell.nix`) si se re-audita: el de
  `netrunner` (ola 9) ya es código-only.
