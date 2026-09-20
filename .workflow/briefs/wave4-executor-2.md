# Brief: Wave 4 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `modules/desktop/hyprland-home.nix`:

1. **Quitar el auto-espejo al arrancar** (causa "pantallas locas"): eliminar el
   bloque `hl.on("monitor.added", function() … monitor-mirror.sh mirror end)` de
   `extraConfig` (y su comentario). El toggle queda manual con `SUPER+D`.
2. **`monitor-mirror.sh` no-op con <2 salidas físicas**: al inicio, tras
   construir `all`, si hay menos de 2 salidas, notificar y salir 0:
   ```bash
   if [ "$(echo "$all" | jq 'length')" -lt 2 ]; then
     notify-send "Solo hay un monitor"
     exit 0
   fi
   ```
   (así no hace nada en la laptop sin monitor externo ni en la pc con una
   pantalla). Actualiza el comentario del bloque.
3. **mpvpaper: un solo proceso** (hoy se lanzan hasta 3 por cambio de wallpaper
   y quedan duplicados). Dos cambios:
   - `wallpaper-set.sh`: **simplificar**. Debe solo (a) guardar la ruta fuente en
     `wallpaper-source.txt` y (b) llamar a `caelestia-wallpaper.sh "$f"`.
     ELIMINA el bloque que extrae el frame con `ffmpeg` y llama a
     `caelestia wallpaper -f …`, y la línea final
     `caelestia scheme set -n cyberpunk`: el esquema es fijo y lo garantiza el
     activation; ya no hay que recalcular Material You en cada wallpaper.
   - `caelestia-wallpaper.sh`: hazlo **idempotente** antes del `pkill`:
     ```bash
     if pgrep -af 'mpvpaper' | grep -qF -- "$wall"; then
       exit 0
     fi
     ```
     (si ya está reproduciendo ese mismo wallpaper, no relanzar). Mantén el
     `pkill -x .mpvpaper-wrapp`.
4. **Helper `caelestia-restart.sh`** (nuevo script executable): la shell en
   runtime se queda en el store viejo tras un rebuild y el IPC falla con
   exit 255. Script:
   ```bash
   #!/usr/bin/env bash
   # Reinicia el shell de Caelestia tras un rebuild (la instancia viva apunta al
   # store anterior y el IPC `caelestia shell ...` falla con exit 255).
   pkill -f 'quickshell.*caelestia-shell' 2>/dev/null
   sleep 0.5
   caelestia shell -d
   ```

## Definition of done

- Sin `monitor.added` en `extraConfig`; `monitor-mirror.sh` con la guarda `<2`.
- `wallpaper-set.sh` sin `caelestia wallpaper` ni `scheme set`; solo guarda
  fuente + llama a `caelestia-wallpaper.sh`.
- `caelestia-wallpaper.sh` con la guarda de idempotencia.
- Existe `caelestia-restart.sh`.
- El verify command pasa. Solo `modules/desktop/hyprland-home.nix` modificado.

## Files you own

- `modules/desktop/hyprland-home.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/caelestia.nix`, `modules/apps/**`,
  `hosts/**`, `home/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `modules/desktop/hyprland-home.nix` es home-side (no hace falta `lib.hm.dag`
  aquí, pero no hay activations).

## Read first

- `modules/desktop/hyprland-home.nix`: `hl.on("monitor.added")` ~líneas 61–67,
  `monitor-mirror.sh` ~512–549, `wallpaper-set.sh`, `caelestia-wallpaper.sh`,
  `mpvpaper-pause.sh`.
- `.workflow/plan.md` → hallazgos de mpvpaper/auto-espejo/shell vieja y Wave 4 T2.

## Verify command

```bash
nix flake check --no-build \
  && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'monitor.added' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/monitor-mirror.sh".text' | grep -q -- '-lt 2' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/caelestia-wallpaper.sh".text' | grep -q 'grep -qF' \
  && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/wallpaper-set.sh".text' | grep -q 'caelestia wallpaper' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/caelestia-restart.sh".text' | grep -q 'pkill'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por cambio lógico.
- Commit ONLY `modules/desktop/hyprland-home.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave4-executor-2` tras cada
  commit. Nunca a `main` ni a otra rama.

## Report back

- Diff resumido, salida del verify, y confirmar que tras cambiar de wallpaper
  solo queda UN proceso `mpvpaper`.
