# Auditoría · Ola 1 — Caelestia: seed, bugs (SUPER+L, OSD brillo, idle/suspend) y paleta cyberpunk

- Fecha: 2026-09-20
- Auditor: sesión fresca (no la del planner ni la de los executors)
- Árbol: `main` integrado, HEAD `1de119a701cddf9da9e8f8efa9e13e4f6bee7dd8`
- Ola a auditar: la 1 del plan rodante de personalización de Caelestia
- Ramas: `wave1-executor-1` (`4ce8184`), `wave1-executor-2` (`43a5ba9`), `wave1-executor-3` (`646f93f`)

---

## 1. Integridad de la integración

- [x] **Los tres worktrees están mergeados en main.** Merges `ed9838d` (e3),
  `e4f5a6a` (e1), `1de119a` (e2); `main` == `origin/main`.
  ```
  git log --graph --oneline -6
  *   1de119a merge: wave 1 wave1-executor-2
  | * 43a5ba9 feat(caelestia): re-aplicar paleta cyberpunk al cambiar wallpaper
  *   e4f5a6a merge: wave 1 wave1-executor-1
  | * 4ce8184 feat(caelestia): figuritas, transparencia, trail y sin autolock
  *   ed9838d merge: wave 1 wave1-executor-3
  | * 646f93f feat(caelestia): esquema cyberpunk en caelestia-cli por overlay
  git rev-parse main origin/main → 1de119a... (idénticos)
  ```
- [x] **`git status` limpio, sin stashes.**
  ```
  git status -sb → ## main...origin/main
  git stash list → (vacío)
  git log --oneline main..<rama> → (vacío en las 3; merge-base == punta de rama)
  ```
- [x] **Diff vs plan (mapa de propiedad).** El diff neto de la ola toca SOLO
  los 3 archivos owned; `flake.lock` intacto.
  ```
  git diff --stat 2ef30b7..main
   flake.nix                         | 127 +++++++++++++++++++++++-
   modules/desktop/caelestia.nix     |  36 +++++------
   modules/desktop/hyprland-home.nix | 101 +++++++++++++---------
  git log --stat por commit:
   646f93f → flake.nix
   4ce8184 → modules/desktop/caelestia.nix
   2a48dce, c24c715, 34d1b0e, 27b5a0c, 43a5ba9 → modules/desktop/hyprland-home.nix
  ```
  Ningún commit de la ola toca `flake.lock` ni archivos fuera del mapa.

## 2. Build y tests (árbol integrado)

- [x] `nix flake check --no-build` → `all checks passed!` (exit 0).
- [x] `nix build --no-link --print-out-paths .#nixosConfigurations.pc.config.system.build.toplevel`
  → `/nix/store/6frf804zl86c4jcd8y8a4svb9ki3zj12-nixos-system-nixos-pc-26.11.20260919.20b1ddd` (exit 0).
- [x] **Verify executor-1** (jq sobre `shellJsonPath`) → `true` (exit 0).
  ```
  {'displayType':'shapes','activeTrail':true,'transparency':{'base':0.34,'layers':0.5,'enabled':true},
   'services':{'useFahrenheit':false,'useFahrenheitPerformance':false},
   'idle':{'lockBeforeSleep':true,'timeouts':[{'idleAction':'dpms off','timeout':600}]}}
  ```
- [x] **Verify executor-2** → todas las greps OK:
  ```
  lock.sh                  → 'caelestia shell lock lock' + 'caelestia shell lock isLocked'
  extraConfig              → 'caelestia:brightnessUp' (x3), 'ignore_alpha = 0.3'
  lock-hibernate.sh        → 'systemctl suspend'
  brightness.sh            → ausente de xdg.configFile (eval false)
  ```
- [x] **Verify executor-3** → `ls .../schemes/cyberpunk/dark.txt` existe (exit 0) y
  el contenido es byte a byte idéntico al brief (`diff` sin diferencias, 110 líneas).
- [x] **Funcional en vivo** (nixos-pc):
  ```
  caelestia-shell ipc call lock isLocked → false (exit 0)
  caelestia shell lock isLocked         → false (exit 0)
  hyprctl globalshortcuts → caelestia:brightnessUp "Increase brightness"
                            caelestia:brightnessDown "Decrease brightness"
  ```
- [ ] **El esquema `cyberpunk` NO se puede activar** → ver F1 (bloqueante).

## 3. Disciplina ponytail

- [x] Diffs mínimos y con tendencia a menos: `caelestia.nix` neto −6,
  `hyprland-home.nix` −22 (retira `brightness.sh` completa, 32 líneas).
- [x] Sin dependencias nuevas: el overlay reusa el patrón `postInstall` ya
  existente (`caelestiaDedupeOverlay`); el watchdog es un servicio systemd de
  usuario; el brillo usa global shortcuts nativos de Caelestia.
- [x] `ponytail:` presente donde se corta una esquina, con su techo:
  `lock-hibernate.sh` («sondeo cada 15 s; "idle" se aproxima con "bloqueado"…
  upgrade: escuchar eventos de lock»). No hay otros atajos sin documentar.
- [x] Sin abstracciones ni boilerplate no pedidos.

## 4. Seguridad

- [x] Sin secretos en el diff de la ola (scan de `ghp_|AKIA|PRIVATE KEY|password|
  secret|token|api_key` → sin coincidencias).
- [x] Sin inputs externos nuevos: config declarativa; el único valor interpolado
  (`$out` en `postInstall`, `${pkgs.caelestia-shell}` en el script) es de build.
- [x] Release gate: no aplica (config personal, no se distribuye) → auditoría
  ligera, según el plan.

---

## Hallazgos

| ID | Severidad | Descripción | Evidencia |
|----|-----------|-------------|-----------|
| **F1** | **Alta / bloqueante** | El esquema `cyberpunk` del overlay está en la ruta equivocada. El CLI exige `schemes/<nombre>/<flavour>/<modo>.txt`, pero el overlay crea `schemes/cyberpunk/dark.txt` (sin subdirectorio de flavour). Por eso `caelestia scheme set -n cyberpunk` **crashea con IndexError** y la paleta nunca se aplica; el objetivo #4 de la ola queda sin cumplir. El verify del brief solo comprobaba la existencia del archivo → falso positivo. | `caelestia scheme list`: `.cyberpunk == {}`, `.catppuccin|keys == ["frappe","latte","macchiato","mocha"]`. Estructura: `cyberpunk/dark.txt` vs `caelestia/default/dark.txt`, `catppuccin/mocha/dark.txt`. `get_scheme_flavours("cyberpunk") == []` (solo cuenta directorios) → `_check_flavour()` hace `flavours[0]` → `IndexError: list index out of range` (reproducido, exit 1, ver abajo). |
| F2 | Media (proceso) | `wallpaper-set.sh` enmascara F1 con `caelestia scheme set -n cyberpunk \|\| true`: el fallo es silencioso en runtime, lo que oculta el bug al humano. | Diff de `43a5ba9`, línea añadida con `\|\| true`. |
| P1 | Menor (proceso) | El brief de executor-3 especificó la ruta equivocada (`cyberpunk/dark.txt`) y su verify no ejercitaba el CLI, solo `ls`. El executor implementó el brief al pie de la letra; la culpa es del brief/plan. El planner debe corregir ambos y re-verificar con `caelestia scheme set`. | `.workflow/briefs/wave1-executor-3.md` tarea 1 + verify; plan.md hallazgo #4. |
| P2 | Menor (proceso) | `plan.md` deja Wave 1 en `planned` con las tareas sin marcar; el planner debe actualizar a `audited`/`rejected` y el decision log con F1. El auditor no edita `plan.md`. | `grep -A3 'Wave 1' .workflow/plan.md`. |
| P3 | Menor (proceso) | `.workflow/audits/wave2.md` y `wave3.md` son del proyecto archivado (ollama/vídeo, fechas 2026-08-14) y colisionan de nombre con las olas 2/3 de este proyecto; conviene archivarlos/renombrarlos antes de escribir las próximas auditorías. | `head -1 .workflow/audits/wave2.md` → «Ola 2 — ollama 0.32.12…». |

### Reproducción de F1

```
$ P=$(nix build --no-link --print-out-paths '.#nixosConfigurations.pc.pkgs.caelestia-cli')
$ XDG_STATE_HOME=/tmp/state XDG_CACHE_HOME=/tmp/cache "$P/bin/caelestia" scheme set -n cyberpunk
Traceback (most recent call last):
  ...
  File ".../caelestia/utils/scheme.py", line 149, in _check_flavour
    self._flavour = flavours[0]
IndexError: list index out of range
EXIT=1
```

### Fix propuesto (probado)

Mover el esquema un nivel: `schemes/cyberpunk/default/dark.txt` en lugar de
`schemes/cyberpunk/dark.txt` (mismo contenido del brief). Con
`scheme_data_dir` apuntando a una copia corregida:
```
flavours cyberpunk (con subdir default/) = ['default']
modes cyberpunk/default = ['dark']
read_colours = [('primary_paletteKeyColor','ff0066'), ('secondary_paletteKeyColor','00aaff'), ...]
```
Es decir: cambiar en `flake.nix` `mkdir -p $scheme_dir/cyberpunk` →
`mkdir -p $scheme_dir/cyberpunk/default` y `cat > $scheme_dir/cyberpunk/default/dark.txt`.
El verify debe ejercitar `caelestia scheme list | jq -e '.cyberpunk|has("default")'`
(o `scheme set -n cyberpunk` con `XDG_STATE_HOME` temporal) en vez de un `ls`.

---

## Veredicto

**REJECTED**

La integración, el build, el resto de fixes y la seguridad están bien: `nix flake
check` y el toplevel de `pc` pasan, los tres merges están en `main`, el diff neto
es exactamente los 3 archivos del mapa de propiedad, sin secretos, y los puntos
#1 (figuritas), #4a (transparencia), #5 (Celsius), #11a (trail), #12 (SUPER+L) y
#8 (OSD de brillo) están implementados y verificados (los comandos IPC y los
global shortcuts funcionan en vivo).

Pero la ola **no puede aprobarse** porque uno de sus entregables centrales —la
paleta cyberpunk (#4)— no funciona: `caelestia scheme set -n cyberpunk` crashea
(F1), el esquema queda inválido en `scheme list` y el error se enmascara con
`|| true`. Hará falta una corrección pequeña y localizada (ruta `cyberpunk/default/`)
en `flake.nix` + corregir el brief y el verify, y re-auditar.

## Handoff pendiente (quién y qué)

- **Planner**: corregir F1 (ruta `cyberpunk/default/` en `flake.nix`), el brief
  de executor-3 y su verify (debe ejecutar el CLI, no solo `ls`); quitar/ajustar
  el `|| true` de `wallpaper-set.sh` para que un fallo no quede oculto; actualizar
  `plan.md` (Wave 1 → rechazada/con fix) y el decision log con F1.
- **Executor (re-trabajo mínimo)**: una sola línea en `flake.nix` (dueño de
  `flake.nix`); opcionalmente `hyprland-home.nix` para el `|| true`.
- **Humano**: no reconstruir todavía; esperar a que la ola 1 pase con el esquema
  corregido. El resto de cambios visuales (figuritas, transparencia, trail,
  Celsius, brillo, lock) sí están listos para validar.
