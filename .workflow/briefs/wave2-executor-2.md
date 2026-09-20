# Brief: Wave 2 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `modules/desktop/hyprland-home.nix`, cuatro cosas:

1. **Monitor a 100 Hz (reproducible)**: el monitor real es `HDMI-A-2`
   1920x1080 a 60 Hz con modo 100 Hz disponible; el rule `DP-1 @170` es
   un cadáver y el catch-all usa `preferred` (60). Borra la línea
   `hl.monitor({ output = "DP-1", mode = "1920x1080@170", ... })` (y su
   comentario) y cambia el catch-all a
   `hl.monitor({ output = "", mode = "highrr", position = "auto", scale = "1" })`.
   Mantén el rule de `Virtual-1`. `highrr` = máxima frecuencia soportada:
   funciona en `pc` (100 Hz), `laptop` y `vm` sin hardcodear nombres.
2. **F2 (auditoría ola 1)**: en `"hypr/scripts/wallpaper-set.sh"`, quita el
   `|| true` de la línea
   `${pkgs.caelestia-cli}/bin/caelestia scheme set -n cyberpunk || true`
   (el esquema ya existe tras el fix de la ola 2; que falle ruidosamente si
   algo se rompe). Actualiza el comentario de esa sección.
3. **Animaciones de workspace (#5)**: el humano quiere recuperar el "bounce
   fuerte pero más natural" y poder probar todos los estilos. En el bloque de
   animaciones de `extraConfig`:
   - agrega `hl.curve("bounce-natural", { type = "bezier", points = { {0.1, 1.4}, {0.3, 1.0} } })`;
   - deja también definida `bounce` (fuerte, `{0.05, 1.8}, {0.2, 1.0}`) si no
     está;
   - pon `hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "bounce-natural", style = "slidevert" })`.
   - Agrega el script `"hypr/scripts/workspace-anim.sh"` (executable) que
     muestre un menú `fuzzel` con presets y los aplique EN VIVO con
     `hyprctl eval "hl.animation({ leaf = 'workspaces', enabled = true,
     speed = 5, bezier = 'CURVE', style = 'STYLE' })"`. Presets a incluir:
     `slide`, `slidevert`, `fade`, `slidefade`, `slidefadevert` × curvas
     `standard`, `overshot`, `bounce`, `bounce-natural` (mínimo: los 5 estilos
     con `bounce-natural`); imprime el preset aplicado y recuerda que es
     temporal (vive hasta el próximo reload/rebuild). Con argumento
     `style curve` aplica directo sin menú.
   - Bind: `hl.bind("SUPER + ALT + A", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/workspace-anim.sh"))`.
4. **Layout como notificación nativa (#2)**: en `"hypr/scripts/switch-layout.sh"`,
   tras `hyprctl switchxkblayout all next`, agrega un `notify-send` real
   (Caelestia pinta las notificaciones DBus arriba-derecha). El toast nativo
   lo apaga executor-4 (`utilities.toasts.kbLayoutChanged=false`), así que este
   `notify-send` no duplica. Usa algo como:
   ```
   layout=$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[0].active_keymap // "cambiada"')
   notify-send -t 2000 -a caelestia -u low "Distribución de teclado" "$layout"
   ```

## Definition of done

- Catch-all de monitores en `highrr`; sin references a `DP-1` ni `@170`.
- `wallpaper-set.sh` sin `|| true` en el `scheme set`.
- Existe `workspace-anim.sh` y el bind `SUPER+ALT+A`; curva `bounce-natural`
  aplicada a `workspaces`.
- `switch-layout.sh` con `notify-send`.
- El verify command pasa. Solo `modules/desktop/hyprland-home.nix` modificado.

## Files you own

- `modules/desktop/hyprland-home.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/caelestia.nix`,
  `modules/apps/**`, `hosts/**`, `home/**`, `.workflow/**` (salvo leer).

## Read first

- `modules/desktop/hyprland-home.nix`: monitores 24–30, animaciones 175–190,
  binds 254–362, `switch-layout.sh` (~línea 800), `wallpaper-set.sh` 602–653.
- `.workflow/plan.md` → hallazgos de monitor y #5, y Wave 2 T2.
- `.workflow/audits/wave1.md` → F2.

## Verify command

```bash
nix flake check --no-build \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'mode = "highrr"' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'bounce-natural' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/workspace-anim.sh".text' | grep -q 'hl.animation' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/switch-layout.sh".text' | grep -q 'notify-send' \
  && ! nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/wallpaper-set.sh".text' | grep -q 'cyberpunk || true'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por cambio lógico (monitor, animación+script, layout, F2).
- Commit ONLY `modules/desktop/hyprland-home.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave2-executor-2` tras cada
  commit. Nunca a `main` ni a otra rama.

## Report back

- Diff resumido, salida del verify, presets incluidos en `workspace-anim.sh`, y
  cualquier choque de bind que hayas detectado con `SUPER+ALT+A`.
