# Brief: Wave 5 · Executor 4

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Cambiar los binds/reglas de terminal a kitty en
`modules/desktop/hyprland-home.nix`, y el terminal por defecto del shell en
`modules/desktop/caelestia.nix`.

1. **`hyprland-home.nix`**:
   - `SUPER + Backspace` → `hl.dsp.exec_cmd("kitty")` (antes `wezterm`).
   - `SUPER + N` (netrunner) → lanzar una kitty **flotante y autónoma**:
     `hl.dsp.exec_cmd("kitty --class netrunner sh -c 'zsh -ic netrunner'")`.
     Agrega una window rule para que `class = "netrunner"` nazca flotante
     (`hl.window_rule({ name = "netrunner-float", match = { class = "netrunner" }, float = true })`).
   - `time-to-work.sh`: la línea de `wezterm` → `kitty` (abre el ws 4).
   - Window rules: agrega `hl.window_rule({ name = "kitty-glass", match = { class = "kitty" }, opacity = "1 override" })`
     para que Hyprland no multiplique la translucidez de kitty (deja que el blur
     del compositor se vea detrás). La regla `wezterm-glass` se queda (fallback).
   - No toques `monitor-mirror.sh` ni lo de la ola 4.
2. **`caelestia.nix`**: en `general.apps`, `terminal = [ "kitty" ]` (hoy
   `[ "wezterm" ]`).

## Definition of done

- Los 3 binds/scripts de terminal usan kitty; `netrunner` flotante.
- Regla `kitty-glass` presente.
- `general.apps.terminal = [ "kitty" ]` en el seed.
- El verify command pasa. Solo `modules/desktop/hyprland-home.nix` y
  `modules/desktop/caelestia.nix` modificados.

## Files you own

- `modules/desktop/hyprland-home.nix`
- `modules/desktop/caelestia.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/**`, `hosts/**`, `home/**`,
  `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `modules/desktop/caelestia.nix` es **system-side** (sin `lib.hm.dag`); aquí no
  hay activations igual.

## Read first

- `modules/desktop/hyprland-home.nix`: binds ~262, window rules ~195–240,
  `time-to-work.sh` ~465–480.
- `modules/desktop/caelestia.nix`: `general.apps` ~67–72.
- `.workflow/plan.md` → Wave 5 T4.

## Verify command

```bash
nix flake check --no-build \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'exec_cmd("kitty")' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'kitty-glass' \
  && nix build --no-link --print-out-paths '.#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath' | xargs jq -e '.general.apps.terminal == ["kitty"]'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por archivo/cambio lógico.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): `git push origin wave5-executor-4`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y recordatorio de que el humano debe borrar
  `~/.config/caelestia/shell.json` para adoptar `terminal = kitty`.
