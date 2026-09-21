# Brief: Wave 9 · Executor 3

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `modules/apps/shell.nix`, dar a `netrunner()` **cierre en cadena** como ya lo
tiene `hyprdev()`: si se cierra cualquiera de las 2 ventanas (btop o nvtop), la
otra se cierra también. Requisito explícito del humano ("al comando netrunner lo
único que le falta es que también se cierre en cadena").

`netrunner` actual (no cambiar su semántica):
- la terminal que lo invoca **se convierte en btop** (`exec btop`);
- `nvtop` sale en **otra** ventana kitty independiente, **al lado** (nunca debajo)
  vía `hyprctl dispatch 'hl.dsp.layout("preselect r")'`;
- el bind `SUPER+N` la lanza desde kitty (executor de la ola 8).

Patrón a copiar de `hyprdev()` (mismo archivo, léelo completo):
- capturar **antes del `exec`** el address y el pid de la ventana invocadora
  (`hyprctl -j activewindow`; `$KITTY_PID` si existe);
- lanzar nvtop con un wrapper `setsid zsh -c 'print -r -- $$ >> "$pidf"; exec kitty ...'`
  que anota su pid en un `pidfile` **antes** del `exec kitty` (así el pid es el de
  kitty);
- watcher en sesión propia (`setsid zsh -f -c … &`) que **se arma con 2**:
  la address de la invocadora sigue viva **y** existe un cliente con título
  `netrunner-nvtop`; al bajar a 1, `kill` de los pids del pidfile + el de la
  invocadora y salir. Timeout de arranque ~30 s (como hyprdev) y salida si nunca
  se arma.
- **No** usar `hyprctl dispatch closewindow` (mata la ventana activa si el
  selector no matchea); matar por PID, como hyprdev.

El watcher debe invocarse con una etiqueta reconocible `netrunner-watch` y el
spawn con `netrunner-spawn` (el verify las busca).

No toques la lógica de `hyprdev()` (ya auditada en la ola 8).

## Definition of done

- `netrunner()` mantiene: invocadora → btop, nvtop al lado, sin `--cwd`.
- Existe un watcher de cierre en cadena (2 ventanas) con pidfile, análogo a
  `hyprdev()`.
- El verify command pasa.

## Files you own

- `modules/apps/shell.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/kitty.nix`, `modules/desktop/**`,
  `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo home-side; no hay activations. `initContent` es una string de zsh
  embebida: cuidado con el escaping de `$` (usa `''${…}` de Nix donde aplique,
  igual que el resto del archivo).

## Read first

- `modules/apps/shell.nix` → `hyprdev()` (líneas ~81–132) y `netrunner()`
  (~62–71).
- `git show b041d24^:modules/apps/shell.nix` (watcher wezterm original, por si
  ayuda).
- `.workflow/audits/wave8.md` §3 E1 (por qué NO usar `closewindow`).

## Verify command

```bash
nix flake check --no-build && c="$(nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.zsh.initContent')" && printf '%s' "$c" | grep -q 'netrunner-nvtop' && printf '%s' "$c" | grep -q 'netrunner-watch' && ! printf '%s' "$c" | grep -q -- '--cwd'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit.
- Commit ONLY `modules/apps/shell.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave9-executor-3`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y cómo probarías el cierre en cadena (qué comando y
  qué esperar).
