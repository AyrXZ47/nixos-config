# Brief: Wave 5 · Executor 3

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Migrar las funciones zsh de terminal de wezterm a kitty en
`modules/apps/shell.nix`: `dev()`, `hyprdev()` y `netrunner()`. Mantén los
mismos nombres y el mismo espíritu; solo cambia el motor.

Contexto: hoy usan `wezterm cli split-pane` / `wezterm start` y guardan
`$WEZTERM_PANE`. Con kitty se usa `kitty @ launch` (el control remoto queda
habilitado en `kitty.nix` por la ola 5). La guarda cambia a kitty
(`$KITTY_WINDOW_ID`).

1. **`hyprdev()` — la geometría que pidió el humano.** Debe crear UN panel kitty
   con 4 splits:
   - opencode arriba-derecha (~75% ancho × 65% alto),
   - nvim arriba-izquierda,
   - pipes-rs abajo-izquierda,
   - terminal libre abajo-derecha.
   Con `kitty @ launch --location=vsplit|hsplit --bias=N` (bias = % que se lleva
   el panel nuevo). Orden sugerido: nvim base → vsplit bias 75 (opencode, derecha)
   → la zona izquierda hsplit bias 35 (pipes abajo) → la derecha hsplit bias 35
   (libre abajo). Ajusta si el bias no reparte como se pide.
   - `opencode` con `zsh -ic "opencode"`, `pipes` con
     `zsh -ic "pipes-rs -k heavy,dots,sus --rainbow 0 --palette darker -d 50 -r 0"`,
     nvim con `zsh -ic "nvim; exec zsh"`, libre `zsh`.
   - **Fallback aceptado**: si los splits no dan la geometría, 4 ventanas kitty
     independientes tileadas por Hyprland (equivalente al wezterm de antes), con
     `--class hyprdev-$runid`.
   - Conserva el comportamiento de cierre en cadena (cerrar la terminal libre
     cierra las demás) si es viable con kitty; si no, simplifícalo y repórtalo.
2. **`netrunner()`**: dividir el kitty ACTUAL (btop izquierda / nvtop derecha),
   `exec btop` como antes. La guarda pasa a `$KITTY_WINDOW_ID`. El bind de
   Hyprland que la lanza lo cambia executor-4.
3. **`dev()`**: misma migración que netrunner (splits de kitty en vez de
   `wezterm cli split-pane`). Si el humano ya no la usa, déjala funcionando igual
   (barato) en vez de borrarla.

No toques el resto del archivo (yt-dlp, whisper, zsh, etc.).

## Definition of done

- `shell.nix` no usa `wezterm` ni `$WEZTERM_PANE` en `dev`/`hyprdev`/`netrunner`.
- `hyprdev` implementa la geometría o el fallback documentado.
- El verify command pasa. Solo `modules/apps/shell.nix` modificado.

## Files you own

- `modules/apps/shell.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/kitty.nix`, `modules/apps/wezterm.nix`,
  `modules/desktop/**`, `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo home-side; no hay activations.

## Read first

- `modules/apps/shell.nix`: `netrunner()` ~59, `dev()` ~70, `hyprdev()` ~100–179.
- `.workflow/plan.md` → Wave 5 T3 y los requisitos de kitty/hyprdev/netrunner.

## Verify command

```bash
nix flake check --no-build && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.zsh.initContent' | grep -q 'kitty @ launch' && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.zsh.initContent' | grep -q 'wezterm cli split-pane'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por función (hyprdev, netrunner/dev).
- Commit ONLY `modules/apps/shell.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave5-executor-3`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify, la geometría final de los splits (o el fallback
  elegido), y cómo se cierra la sesión hyprdev.
