# Brief: Wave 6 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Ajustar Hyprland y Caelestia a la vuelta de ventanas kitty independientes, y
forzar a Caelestia a mostrar Mixxx como player activo.

1. **`modules/desktop/hyprland-home.nix`**:
   - El bind `SUPER + N` pasa a
     `hl.bind("SUPER + N", hl.dsp.exec_cmd("zsh -ic netrunner"))` (netrunner
     mismo abre sus ventanas; ya no hay que envolver en `kitty --class ...`).
   - Quita la window rule `netrunner-float` (las ventanas ahora son clase
     `kitty`, esa regla ya no matchea y no queremos distinguirlas).
   - Mantén la regla `kitty-glass` y `wezterm-glass`.
   - No toques `monitor-mirror.sh` ni nada de las olas 4/5.
2. **`modules/desktop/caelestia.nix`**: en `services`, pon
   `defaultPlayer = "Mixxx"` (hoy `"mpv"`) para que el "MPRIS falso" de Mixxx
   (executor-4) sea el player activo del dashboard. Opcional: en
   `bar.workspaces.windowIcons` puedes quitar las entradas ya muertas
   (`hyprdev.*`/wezterm) porque el parche QML de la ola 4 usa
   `Icons.getAppIcon(class)` y ya no lee `windowIcons`; si lo haces, documenta.

## Definition of done

- `SUPER+N` llama a `netrunner` (sin `kitty --class netrunner`), sin la regla
  `netrunner-float`.
- `services.defaultPlayer == "Mixxx"` en el seed.
- El verify command pasa. Solo `modules/desktop/hyprland-home.nix` y
  `modules/desktop/caelestia.nix` modificados.

## Files you own

- `modules/desktop/hyprland-home.nix`
- `modules/desktop/caelestia.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/**`, `hosts/**`, `home/**`,
  `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `modules/desktop/caelestia.nix` es **system-side** (sin `lib.hm.dag`).

## Read first

- `modules/desktop/hyprland-home.nix`: binds ~260–275, window rules ~200–215.
- `modules/desktop/caelestia.nix`: `services` (~líneas 512–525).
- `.workflow/plan.md` → Wave 6 T2 y hallazgo de splits.

## Verify command

```bash
nix flake check --no-build \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'zsh -ic netrunner' \
  && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'netrunner-float' \
  && nix build --no-link --print-out-paths '.#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath' | xargs jq -e '.services.defaultPlayer == "Mixxx"'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por archivo.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): `git push origin wave6-executor-2`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y recordatorio de re-sembrar `shell.json`.
