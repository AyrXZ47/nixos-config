# Brief: Wave 7 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Reimplementar `hyprdev` y `netrunner` en `modules/apps/shell.nix` como las
funciones wezterm originales, pero con ventanas kitty independientes y los
requisitos EXACTOS del humano. Referencia obligatoria:
```bash
git show b041d24^:modules/apps/shell.nix   # funciones netrunner() y hyprdev() wezterm
```
Lee esas funciones completas (incluido el watcher de cierre en cadena) antes de
escribir nada.

**Aviso**: la versión actual usa `kitty --cwd`, flag **inexistente** en kitty
0.48 → kitty salía al instante. Usa `kitty -d <dir>` en todo.

### `hyprdev`
1. Se invoca **desde una terminal kitty** (guarda `$KITTY_WINDOW_ID`). Esa
   terminal **se reutiliza**: se convierte en nvim (`exec`) y NO se abre una 5ª
   ventana inútil. Solo se lanzan **3 ventanas nuevas** (opencode, libre,
   pipes-rs) — 4 en total.
2. **Cierre en cadena (tipo IDE)**: si se cierra CUALQUIERA de las 4, se cierran
   las demás. Adapta el watcher wezterm: rastrea las ventanas por título
   (`hyprdev-<runid>-<rol>`, con `-T`) y/o por address de Hyprland
   (`hyprctl -j clients`), con `armed` cuando están las 4; al bajar de 4, cierra
   las restantes (`hyprctl dispatch closewindow address:<a>`). La ventana
   invocadora: captura su address (`hyprctl -j activewindow`) ANTES del `exec`
   nvim para que el watcher también la vigile.
3. `repo` por argumento o `$PWD`; `runid` único por sesión.
4. Lanza el watcher con `setsid ... &` ANTES del `exec`, para que sobreviva.

### `netrunner`
1. Se invoca desde una terminal kitty (guarda `$KITTY_WINDOW_ID`). Esa terminal
   **se convierte en btop** (`exec btop`).
2. **nvtop** sale en OTRA ventana kitty independiente, **al lado** (nunca debajo).
   Si con el tiling por defecto queda debajo, fuérzalo (window rule `force_split`
   o `hyprctl`). nvtop se lanza ANTES del `exec btop`.
3. Si se invoca sin terminal (p.ej. el bind), el bind la lanza (executor-2).

## Definition of done

- `shell.nix` sin `--cwd`; `hyprdev`/`netrunner` con la lógica nueva (invocadora
  reutilizada, 3/1 ventanas nuevas, watcher de cierre en cadena).
- El verify command pasa. Solo `modules/apps/shell.nix` modificado.

## Files you own

- `modules/apps/shell.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/kitty.nix`,
  `modules/desktop/**`, `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo home-side; no hay activations.

## Read first

- `modules/apps/shell.nix`: `netrunner()` y `hyprdev()` actuales.
- `git show b041d24^:modules/apps/shell.nix` (versión wezterm, con el watcher).
- `.workflow/plan.md` → Wave 7 T1 y hallazgo del `--cwd`.
- `kitty --help` → `-d, --working-directory`; `-T, --title`.

## Verify command

```bash
nix flake check --no-build && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.zsh.initContent' | grep -q -- '--cwd' && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.zsh.initContent' | grep -q 'exec btop' && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.zsh.initContent' | grep -q 'closewindow'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por función.
- Commit ONLY `modules/apps/shell.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave7-executor-1`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify, y **cómo probaste hyprdev/netrunner en vivo** (V los
  usa a diario): cuántas ventanas abre, cómo se comporta el cierre en cadena y
  si nvtop queda al lado de btop.
