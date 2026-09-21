# Brief: Wave 6 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

`modules/desktop/hyprland-home.nix` y `modules/desktop/caelestia.nix`:

1. **hyprland-home.nix — bind netrunner**: `SUPER + N` pasa a
   `hl.bind("SUPER + N", hl.dsp.exec_cmd("zsh -ic netrunner"))` (netrunner
   mismo abre sus ventanas; ya no se envuelve en `kitty --class ...`).
2. **hyprland-home.nix — quitar `netrunner-float`**: las ventanas ahora son
   clase `kitty` y esa regla ya no aplica.
3. **hyprland-home.nix — cliphist a 20**: `xdg.configFile."cliphist/config".text`
   pasa de `max-items 6` a `max-items 20`.
4. **hyprland-home.nix — `caelestia-restart.sh` self-heal**: si
   `~/.config/caelestia/shell.json` no existe, copiarlo de
   `~/.config/caelestia/shell.default.json` (que crea el punto 6) antes de
   reiniciar la shell. Motivo: borrar `shell.json` para adoptar el seed y
   reiniciar sin rebuild deja la shell en DEFAULTS (sin blur, sin cava, sin
   acciones del launcher).
5. **caelestia.nix — `defaultPlayer = "Mixxx"`** en `services` (hoy `"mpv"`),
   para que el MPRIS falso de Mixxx (executor-4) sea el player activo.
6. **caelestia.nix — exponer el seed como archivo estable**: dentro de
   `home-manager.users.yovick`, agregar
   `xdg.configFile."caelestia/shell.default.json".source = config.modules.desktop.caelestia.shellJsonPath;`
   (symlink al seed del store; el restart lo copia si falta). No cambies el
   activation existente.

## Definition of done

- `SUPER+N` llama a `netrunner`; sin regla `netrunner-float`.
- `max-items 20`.
- `caelestia-restart.sh` re-siembra `shell.json` si falta.
- `services.defaultPlayer == "Mixxx"`.
- Existe `~/.config/caelestia/shell.default.json` (symlink al seed).
- El verify command pasa. Solo los 2 archivos modificados.

## Files you own

- `modules/desktop/hyprland-home.nix`
- `modules/desktop/caelestia.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/**`, `hosts/**`, `home/**`,
  `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `modules/desktop/caelestia.nix` es **system-side** (sin `lib.hm.dag`). El
  `xdg.configFile` va dentro de `home-manager.users.yovick`.

## Read first

- `modules/desktop/hyprland-home.nix`: bind ~320, window rules ~200,
  `cliphist/config` ~463, `caelestia-restart.sh`.
- `modules/desktop/caelestia.nix`: `services` ~512, activation ~707.
- `.workflow/plan.md` → hallazgo "`shell.json` ausente → defaults" y Wave 6 T2.

## Verify command

```bash
nix flake check --no-build \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'zsh -ic netrunner' \
  && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'netrunner-float' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."cliphist/config".text' | grep -q 'max-items 20' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/caelestia-restart.sh".text' | grep -q 'shell.default.json' \
  && nix build --no-link --print-out-paths '.#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath' | xargs jq -e '.services.defaultPlayer == "Mixxx"'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por cambio lógico.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): `git push origin wave6-executor-2`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y confirmar que el activation del seed sigue intacto.
