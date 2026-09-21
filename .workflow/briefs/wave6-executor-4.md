# Brief: Wave 6 · Executor 4

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Crear un **MPRIS falso de Mixxx** ("el engaño"): Mixxx 2.5.6 no expone MPRIS,
así que publicamos nosotros `org.mpris.MediaPlayer2.mixxx` para que el dashboard
de Caelestia muestre el logo de Mixxx y active el bongocat cuando suene audio de
Mixxx, en vez de "Nothing playing" / "No media".

1. **Nuevo `modules/apps/mixxx-mpris.nix`**:
   - Script Python (usa `pkgs.writers.writePython3Bin` con
     `libraries = [ pkgs.python3Packages.pydbus pkgs.python3Packages.pygobject3 ]`)
     que publica el servicio D-Bus `org.mpris.MediaPlayer2.mixxx` en el bus de
     sesión con las interfaces `org.mpris.MediaPlayer2` y
     `org.mpris.MediaPlayer2.Player`.
   - **Estado**: cada ~1 s lee `pw-dump` (JSON de PipeWire; ya está en PATH) y
     busca un nodo de audio cuyo `application.name` (o
     `application.process.binary`) sea `mixxx`. Si su estado es `running` →
     `PlaybackStatus = "Playing"`; si existe pero `idle`/`suspended` →
     `"Paused"`; si no existe → `"Stopped"`.
   - **Metadata**: `xesam:title = "Mixxx"`, `mpris:artUrl = "file:///run/current-system/sw/share/icons/hicolor/256x256/apps/mixxx.png"`
     (verificado que existe), `mpris:trackid` con un object path válido.
   - **Properties**: `Identity = "Mixxx"`, `DesktopEntry = "org.mixxx.Mixxx"`,
     `CanPlay = true`, `CanPause = true`, `CanGoNext/Previous = false`.
   - **Métodos** `PlayPause/Play/Pause/Next/Previous/Stop/Seek`: no-op (Mixxx no
     tiene API de control remoto). Que no revienten.
   - `ponytail:` comentario con el techo (heurística de PipeWire; sin metadatos
     de pista porque Mixxx no los expone).
2. **`home/default.nix`**: importa `../modules/apps/mixxx-mpris.nix`.
3. En el módulo, `systemd.user.services.mixxx-mpris` (`WantedBy =
   graphical-session.target`, `Restart = always`, `RestartSec = 5`) que corra el
   script; y `home.packages` con el script.

Notas: `pactl` NO está en el sistema, usa `pw-dump`. `python3Packages.pydbus` y
`dbus-python` existen en nixpkgs. Si `pydbus` da problemas, usa `dbus-python`
con `GLib.MainLoop` y repórtalo.

## Definition of done

- Existe el módulo, importado, con el servicio systemd de usuario.
- El verify command pasa. Solo `modules/apps/mixxx-mpris.nix` (nuevo) y
  `home/default.nix` modificados.

## Files you own

- `modules/apps/mixxx-mpris.nix` (nuevo)
- `home/default.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/**`, `modules/apps/shell.nix`,
  `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo home-side; el `systemd.user.services` de Home Manager sirve.

## Read first

- `.workflow/plan.md` → hallazgo #9 (Mixxx sin MPRIS) y Wave 6 T4.
- `services/Players.qml` de Caelestia (qué propiedades lee: `trackTitle`,
  `trackArtUrl`, `isPlaying`, `identity`).
- `modules/apps/miracast.nix` como ejemplo de módulo home-side simple.

## Verify command

```bash
nix flake check --no-build && nix eval '.#nixosConfigurations.pc.config.home-manager.users.yovick.systemd.user.services.mixxx-mpris.enable' | grep -q true 2>/dev/null || nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.systemd.user.services.mixxx-mpris.Service.ExecStart' | grep -q mixxx-mpris
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `feat(mixxx): MPRIS falso para el dashboard de caelestia`.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): `git push origin wave6-executor-4`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify, cómo detectas el audio de Mixxx y cualquier ajuste
  de librería. Recuerda: la validación real (Mixxx sonando → logo + bongocat)
  la hace el humano.
