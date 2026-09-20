# Brief: Wave 3 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `modules/desktop/hyprland-home.nix`:

1. **Animación de workspace DEFINITIVA (#5)**: donde hoy está
   `hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "bounce-natural", style = "slidevert" })`,
   poner
   `hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "overshot", style = "slidefadevert" })`.
   Deja las curvas `bounce`/`bounce-natural` definidas (las usa el selector).
   Actualiza el comentario de la sección.
2. **Quitar el cast VNC (#nuevo)**: borrar los dos binds
   `hl.bind("SUPER + ALT + D", ... "cast-tablet")` y
   `hl.bind("SUPER + ALT + SHIFT + D", ... "cast-tablet extend")` (y sus
   comentarios). Se retira TODO el cast VNC (el módulo lo borra executor-2).
3. **`SUPER + D` = toggle espejo/extender**: agregar
   `hl.bind("SUPER + D", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/monitor-mirror.sh"))`.
   Mantén el bind existente `SUPER + SHIFT + D` (mismo script).
4. **Arreglar el bug de espejo (#nuevo)**: en `monitor-mirror.sh`, el primario
   se elegía con `max_by(.width * .height * .refreshRate)`, y la salida
   `HEADLESS-TABLET` (1920x1200) le ganaba al monitor físico → el físico
   terminaba espejando la salida headless del cast (`mirrorOf` invertido).
   Cambios:
   - al construir `all`, excluir salidas headless:
     `select(.name | startswith("HEADLESS") | not)` (además de `disabled == false`);
   - elegir el primario por monitor **enfocado**:
     `primary=$(echo "$all" | jq -r '[.[] | select(.mirrorOf == "none")] | (map(select(.focused == true))[0] // .[0]) | .name')`;
   - actualizar el comentario `ponytail:` explicando el criterio nuevo.
5. **Allowlist en `workspace-anim.sh` (H2 de la auditoría ola 2)**: antes de
   interpolar `style`/`curve` en `hyprctl eval`, valida contra arrays definidos
   `allowed_styles=(slide slidevert fade slidefade slidefadevert)` y
   `allowed_curves=(standard overshot bounce bounce-natural)`; si no coincide,
   error y salida (no ejecutes string arbitrario). Los presets del menú ya salen
   de esos arrays.

## Definition of done

- `workspaces` usa `slidefadevert` + `overshot`.
- Cero referencias a `cast-tablet` en el archivo; `SUPER + D` bindeado.
- `monitor-mirror.sh` sin `refreshRate` en la selección; excluye `HEADLESS`.
- `workspace-anim.sh` con `allowed_styles`/`allowed_curves`.
- El verify command pasa. Solo `modules/desktop/hyprland-home.nix` modificado.

## Files you own

- `modules/desktop/hyprland-home.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/**`, `modules/desktop/caelestia.nix`,
  `hosts/**`, `home/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `modules/desktop/hyprland-home.nix` es home-side (lo importa
  `home/default.nix` vía `hyprland.nix`), pero aquí no hay activations.

## Read first

- `modules/desktop/hyprland-home.nix`: animaciones 175–195, binds 254–270
  (`SUPER+...D`), `monitor-mirror.sh` 513–545, `workspace-anim.sh` (~línea 916).
- `.workflow/plan.md` → hallazgos de monitor/#5/cast y Wave 3 T1.
- `.workflow/audits/wave2.md` → H2.

## Verify command

```bash
nix flake check --no-build \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'style = "slidefadevert"' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'bezier = "overshot"' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'hl.bind("SUPER + D"' \
  && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'cast-tablet' \
  && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/monitor-mirror.sh".text' | grep -q 'refreshRate' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/workspace-anim.sh".text' | grep -q 'allowed_styles'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por cambio lógico.
- Commit ONLY `modules/desktop/hyprland-home.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave3-executor-1` tras cada
  commit. Nunca a `main` ni a otra rama.

## Report back

- Diff resumido, salida del verify, y explicar brevemente la lógica nueva de
  elección de primario en `monitor-mirror.sh`.
