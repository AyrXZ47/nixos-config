# Brief: Wave 1 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Arreglar bugs y conectar servicios en `modules/desktop/hyprland-home.nix`,
sin tocar nada más:

1. **IPC roto → SUPER+L no bloquea (#12)**: el CLI de Caelestia espera
   `caelestia shell <target> <func>`, NO `caelestia shell ipc call <target>
   <func>` (el CLI vuelve a anteponer `ipc call` y devuelve "Target not found").
   - En `"hypr/scripts/lock.sh"`: `caelestia shell ipc call lock lock` →
     `caelestia shell lock lock`; y el sondeo
     `caelestia shell ipc call lock isLocked` → `caelestia shell lock isLocked`.
   - En `"hypr/scripts/wallpaper-set.sh"`: el `caelestia shell ipc call lock
     isLocked` del bucle de espera → `caelestia shell lock isLocked`.
2. **OSD de brillo (#8)**: los binds de brillo llaman a `brightness.sh`, que usa
   `brightnessctl`/`ddcutil` por fuera y por eso Caelestia no pinta el OSD.
   Reemplazar TODOS los binds de brillo por los global shortcuts de Caelestia
   (que ya manejan panel interno y DDC/CI y disparan el OSD):
   - `XF86MonBrightnessUp` / `XF86MonBrightnessDown`
   - `SUPER + F12` / `SUPER + F11`
   - `SUPER + XF86AudioRaiseVolume` / `SUPER + XF86AudioLowerVolume`
   Usar `hl.dsp.global("caelestia:brightnessUp")` /
   `hl.dsp.global("caelestia:brightnessDown")` (los de teclas multimedia con
   `{ locked = true, repeating = true }`).
   Eliminar el bloque `"hypr/scripts/brightness.sh"` completo (ya es redundante).
3. **Blur con la transparencia nueva (#4b)**: bajar `ignore_alpha` de la regla
   `caelestia-drawers-blur` de `0.8` a `0.3` (el nuevo
   `transparency.base` es 0.34; `ignore_alpha` debe quedar por debajo para que
   Hyprland no descarte el blur). Actualizar el comentario de la regla.
4. **Watchdog lock→hibernar (#13)**: agregar
   `"hypr/scripts/lock-hibernate.sh"` (executable) y un
   `systemd.user.services.caelestia-lock-hibernate` (`WantedBy =
   [ "graphical-session.target" ]`, `Restart = "always"`, `RestartSec = 5`)
   que lo corra. El script sondea cada 15 s con
   `caelestia-shell ipc call lock isLocked` (usa el binario directo, NO el CLI,
   para no depender del wrapper); si lleva ≥ 300 s bloqueado ejecuta
   `systemctl suspend-then-hibernate 2>/dev/null || systemctl suspend` y
   resetea el contador al desbloquear. `ponytail:` comentario con el techo
   (granularidad 15 s; "idle" ≈ "bloqueado").
   OJO: en `pc` y `laptop` no hay swap en disco (solo zram) → la hibernación
   real no es posible; `suspend-then-hibernate` cae a suspender. Dejarlo así y
   reportarlo.
5. **Paleta cyberpunk persistente**: en `"hypr/scripts/wallpaper-set.sh"`, al
   final del paso (2), agregar
   `${pkgs.caelestia-cli}/bin/caelestia scheme set -n cyberpunk || true` para
   que cambiar de wallpaper no pise la paleta. DEPENDE de executor-3 (que crea
   el esquema); el `|| true` lo hace inofensivo si aún no existe.

## Definition of done

- `lock.sh` usa `caelestia shell lock lock` / `... lock isLocked`.
- Ningún bind de brillo referencia `brightness.sh`; todos usan
  `caelestia:brightnessUp/Down`; el script `brightness.sh` ya no existe.
- `ignore_alpha = 0.3` en la regla `caelestia-drawers-blur`.
- Existe `lock-hibernate.sh` + su servicio systemd de usuario.
- `wallpaper-set.sh` re-aplica `cyberpunk`.
- El verify command pasa. Solo `modules/desktop/hyprland-home.nix` modificado.

## Files you own

- `modules/desktop/hyprland-home.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/caelestia.nix`,
  `modules/desktop/hyprland.nix`, `modules/apps/**`, `hosts/**`, `home/**`,
  `.workflow/**` (salvo leer).

## Read first

- `modules/desktop/hyprland-home.nix`: binds 254–362, layer rules 241–249,
  `lock.sh` 779–800, `brightness.sh` 525–549, `wallpaper-set.sh` 602–653.
- `.workflow/plan.md` → "Hallazgos" (#8, #12) y Wave 1 T2.
- `modules/desktop/caelestia.nix` (transparencia base 0.34 que pone
  executor-1) — no lo edites, solo para entender el 0.3.

## Verify command

```bash
nix flake check --no-build \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/lock.sh".text' | grep -q 'caelestia shell lock lock' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'caelestia:brightnessUp' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.wayland.windowManager.hyprland.extraConfig' | grep -q 'ignore_alpha = 0.3' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.xdg.configFile."hypr/scripts/lock-hibernate.sh".text' | grep -q 'suspend-then-hibernate'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line
  (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `perf:`,
  `style:`, `build:`, `ci:`, `revert:`, optional `(scope)`). Under ~72 chars.
  No AI attribution, no trailers. En español, estilo del repo.
- One logical change per commit. One commit per task (pueden ser varios
  commits: fix del lock, feat del brillo, feat del watchdog, etc.).
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): commit and push ONLY to your own worktree
  branch — `git push origin wave1-executor-2` — after each commit. Never push
  to `main` or another branch; never merge, rebase, or fast-forward anyone
  else's branch.

## Report back

- Diff resumido (`git diff --stat`), salida del verify, y una nota sobre la
  limitación de hibernación (sin swap en disco → suspende). Reporta si algún
  bind de brillo no podía pasar a global shortcut.
