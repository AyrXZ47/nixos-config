# Auditoría — Ola 2 (Caelestia: fix F1 + monitor + animaciones + NeoCyberVim)

> Auditor: sesión limpia, árbol integrado (`main` = `7fb5cfa`, == `origin/main`).
> Fecha: 2026-09-20. Base de la ola: `164ab72`.
> Evidencia sobre narración: cada check lleva el comando y su salida.

## Alcance auditado

Ola 2 del plan `.workflow/plan.md`: T1 fix F1 (esquema `cyberpunk`),
T2 monitor `highrr` + F2 + animaciones + `workspace-anim.sh` + `notify-send`
layout, T3 NeoCyberVim, T4 toast layout + activation de reproducibilidad.

## 1. Integridad de integración

- [x] **Merges completos.** `git log --merges` muestra los 4 merges de la ola:
      `b618fda` (e1), `792bff3` (e4), `1b47fee` (e2), `7fb5cfa` (e3).
- [x] **Árbol limpio, sin stashes.**
      `git status --porcelain` → vacío; `git stash list` → vacío.
- [x] **main == origin/main.** `git rev-parse main origin/main` → ambos
      `7fb5cfa18763dfa203758343ed0337e02b1ca431`. Sin commits sin pushear.
- [x] **Diff vs plan = solo los 4 archivos del mapa.**
      `git diff --name-only 164ab72..origin/main` →
      `flake.nix`, `modules/apps/neovim.nix`,
      `modules/desktop/caelestia.nix`, `modules/desktop/hyprland-home.nix`.
      Nada fuera del mapa (`.workflow/` no se tocó en esta ola).
- [x] **Cada rama tocó solo su archivo** (`git log --stat` por rama):
      e1 → `flake.nix`; e2 → `hyprland-home.nix` (4 commits);
      e3 → `neovim.nix`; e4 → `caelestia.nix`.
- [x] **Todos los commits son conventional, en español, una línea.**

## 2. Build y tests

- [x] **`nix flake check` COMPLETO (con build)** → `all checks passed!` (exit 0,
      19.3 s).
- [x] **Build del plan** `nix build --no-link
      .#nixosConfigurations.pc.config.system.build.toplevel` → exit 0.
- [x] **Verify e1 (F1, no negociable).** Fix en
      `flake.nix:449-450`: `mkdir -p $scheme_dir/cyberpunk/default` +
      `cat > $scheme_dir/cyberpunk/default/dark.txt`.
      ```
      $ P=$(nix build --no-link --print-out-paths '.#nixosConfigurations.pc.pkgs.caelestia-cli')
      $ XDG_STATE_HOME=$(mktemp -d) XDG_CACHE_HOME=$(mktemp -d) "$P/bin/caelestia" scheme list | jq -e '.cyberpunk.default.primary == "ff0066"'
      true
      ```
      Además el bloqueante real reproducido en vivo:
      ```
      $ caelestia scheme set -n cyberpunk   → EXIT=0   (sin IndexError)
      $ caelestia scheme get -n             → cyberpunk  (EXIT=0)
      ```
      **F1 cerrado con la verificación fuerte que exige el plan.**
- [x] **Verify e2** (monitor `highrr`, `bounce-natural`, `workspace-anim.sh`
      con `hl.animation`, `switch-layout.sh` con `notify-send`, sin
      `cyberpunk || true`) → `E2_EXIT=0`.
- [x] **Verify e3** (`DonJulve/NeoCyberVim` en `theme.lua`) → `E3_EXIT=0`.
- [x] **Verify e4** (`kbLayoutChanged==false` + activation con
      `scheme set -n cyberpunk`) → `E4_EXIT=0`.
- [x] **Dependencia externa de e3 verificada** (no la cubre `flake check`):
      `curl` → `github.com/DonJulve/NeoCyberVim` HTTP 200,
      `colors/NeoCyberVim.lua` HTTP 200, y `lua/NeoCyberVim/init.lua` expone
      `M.setup(options)`, por lo que el `opts = {}` de LazyVim es válido.
- [x] **Deps de runtime de los scripts presentes:** `jq-1.8.2` y
      `fuzzel-1.14.1` en systemPackages; `libnotify-0.8.8` en home.packages.
- [x] **API en vivo existe:** `hyprctl eval <code> → Issue a Lua string to
      execute` en Hyprland 0.56.2; `hl.animation`/`hl.monitor` ya se usaban en
      el repo (`hyprctl eval` en mirror/touchpad/decoración), no es una API
      nueva.

## 3. Disciplina ponytail

- [x] **Sin dependencias nuevas.** `flake.lock` intacto (no aparece en el
      diff); nada nuevo en `home.packages`/`systemPackages`.
- [x] **Sin abstracciones no pedidas.** Cambios mínimos por tarea: F1 = 2
      líneas; neovim = 4 líneas; caelestia = flag + activation pedidos; el
      grueso de hyprland es el script `workspace-anim.sh` explícitamente
      requerido.
- [x] **`ponytail:` presente donde se corta una esquina deliberada:**
      `caelestia.nix` (activation que fija `cyberpunk` a propósito, con la vía
      de escape documentada) y `hyprland-home.nix:524` (selección de monitor
      primario por área×Hz).
- Nota menor (no bloquea): `workspace-anim.sh` añade un `notify-send` de
      confirmación no pedido por el brief; es 1 línea y útil.

## 4. Seguridad

- [x] **Sin secretos.** `git diff 164ab72..origin/main` filtrado por
      `password|secret|token|api_key|PRIVATE KEY|ghp_` → sin coincidencias.
- [x] **Trust boundaries.** El diff solo escribe un esquema de colores y
      scripts locales; el activation usa guarda `command -v caelestia`. Los
      scripts pasan datos de `hyprctl`/args locales, no input externo.
- [x] **Release gate no aplica**: este proyecto no se distribuye (plan:
      "auditoría ligera, sin `security-audit`"). No hay dependencias nuevas.
- [x] **Licencias**: sin deps nuevas → sin cambio de licencias.

## 5. Handoff

- [x] Resultado escrito en este archivo.
- [ ] **Pendiente (planner)**: decision log y estado de la tabla de olas en
      `.workflow/plan.md` (Wave 2 sigue como `planned`); gate de la ola 3.
- Recomendación de housekeeping (no bloquea): quedan los 4 worktrees
      `wave2-executor-*` en `git worktree list`; conviene `git worktree remove`
      tras la auditoría.

## Hallazgos

| # | Severidad | Hallazgo | Evidencia / Acción |
|---|-----------|----------|--------------------|
| H1 | Info | Validación visual en vivo pendiente (humano): 100 Hz, selector `SUPER+ALT+A`, `notify-send` de layout, NeoCyberVim. No verificable sin sesión Hyprland; API y patrón sí verificados. | Pasos del plan tras `nixos-rebuild switch --flake .#pc`. Owner: humano. |
| H2 | Info | `workspace-anim.sh` interpola `style`/`curve` de la CLI en `hyprctl eval` sin allowlist. Solo afecta al propio usuario (no cruza trust boundary). | Bajo; opcional validar contra los arrays ya definidos. |
| H3 | Info | Worktrees `wave2-executor-*` sin retirar. | `git worktree list`. |
| H4 | Info | `plan.md` no actualizado con el estado/decisiones tras la ola 2. | Tarea del planner al re-planificar la ola 3. |

Sin hallazgos bloqueantes. F1 (bloqueante de la ola 1) queda **cerrado**.

## Veredicto

**APPROVED** — la ola 2 puede darse por integrada y auditada; la ola 3
(parches QML del overlay) puede empezar. H1–H4 son informativos/de housekeeping,
sin condiciones de aprobación.
