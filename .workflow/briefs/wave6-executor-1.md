# Brief: Wave 6 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Revertir los splits internos de kitty en `modules/apps/shell.nix`. El humano
los rechazó: quiere **ventanas de terminal INDEPENDIENTES** tileadas por
Hyprland (para ver el wallpaper por los gaps in/out), como hacía wezterm. Nada
de `kitty @ launch --location=vsplit/hsplit`.

1. **`hyprdev()`**: lanzar **4 ventanas kitty independientes**, una por rol, con
   el orden/roles de antes: nvim, opencode, terminal libre, pipes-rs
   (`zsh -ic "pipes-rs -k heavy,dots,sus --rainbow 0 --palette darker -d 50 -r 0"`).
   Usa `--cwd "$repo"` y **la clase por defecto** (`kitty`): así el dedupe de
   `Workspace.qml` colapsa las 4 en UN icono y `Icons.getAppIcon("kitty")` da el
   icono real. Conserva la espera de que las N ventanas existan (poll por
   `hyprctl -j clients` con la clase `kitty` y el cwd/título es frágil); si no es
   viable, lanza secuencialmente y repórtalo. La cadena de cierre (cerrar la
   libre cierra las demás) se puede simplificar: cada ventana es independiente.
2. **`netrunner()`**: lanzar **2 ventanas kitty independientes** (btop y nvtop),
   sin splits. El bind de Hyprland lo ajusta executor-2.
3. **`dev()`**: si la mantienes, mismo criterio que netrunner (ventanas
   independientes); si no aporta, elimínala y repórtalo.
4. Elimina `$KITTY_WINDOW_ID` y cualquier `kitty @ launch`.

Sintaxis: `kitty [opciones] <programa> <args>`; p.ej.
`kitty --cwd "$repo" zsh -ic "nvim; exec zsh"`.

## Definition of done

- `shell.nix` sin `kitty @ launch` ni `--location=`.
- `hyprdev` abre 4 ventanas independientes; `netrunner` 2.
- El verify command pasa. Solo `modules/apps/shell.nix` modificado.

## Files you own

- `modules/apps/shell.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/kitty.nix`,
  `modules/desktop/**`, `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo home-side; no hay activations.

## Read first

- `modules/apps/shell.nix`: `netrunner()` ~56–95, `hyprdev()` ~99–185.
- `.workflow/plan.md` → hallazgo "Splits de kitty rechazados".

## Verify command

```bash
nix flake check --no-build && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.zsh.initContent' | grep -q -- '--location=' && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.zsh.initContent' | grep -q 'kitty'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por función.
- Commit ONLY `modules/apps/shell.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave6-executor-1`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y cómo quedó el spawn/cierre de las ventanas.
