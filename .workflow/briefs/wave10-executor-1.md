# Brief: Wave 10 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Cerrar el gap de reproducibilidad entre hosts de Caelestia: hoy el activation
`caelestiaSeedConfig` (`modules/desktop/caelestia.nix`) solo siembra
`~/.config/caelestia/shell.json` si **no existe**, así que un host con un
`shell.json` viejo (barra/transparencia/acciones viejas) nunca adopta el seed
nuevo. Hacer que re-siembre **también cuando el seed del repo cambie**, sin
pisar ediciones de Nexus cuando el seed no cambió.

Implementación (mínima, sin dependencias nuevas):

1. En el `let` del módulo, extraer el JSON y su hash una sola vez:
   ```nix
   shellJson = builtins.toJSON shellConfig;
   shellJsonHash = builtins.hashString "sha256" shellJson;
   ```
   y usar `shellJson` en la línea que hoy hace
   `modules.desktop.caelestia.shellJsonPath = pkgs.writeText "caelestia-shell.json" (builtins.toJSON shellConfig);`
   → `pkgs.writeText "caelestia-shell.json" shellJson`.

2. En el `data` del activation `caelestiaSeedConfig`, añadir un sidecar con el
   hash del seed y comparar:
   ```bash
   f="$HOME/.config/caelestia/shell.json"
   h="$HOME/.config/caelestia/.shell-seed.sha256"
   mkdir -p "$(dirname "$f")"
   # Symlink al store (read-only) de una generación anterior: fuera.
   if [ -L "$f" ]; then rm -f "$f"; fi
   new="${shellJsonHash}"
   old="$(cat "$h" 2>/dev/null || true)"
   # Re-siembra si falta O si el seed del repo cambió (reproducibilidad).
   # Si existe y el seed NO cambió, se respeta lo editado en Nexus.
   if [ ! -f "$f" ] || [ "$old" != "$new" ]; then
     cp ${config.modules.desktop.caelestia.shellJsonPath} "$f"
     chmod u+w "$f"
   fi
   printf '%s\n' "$new" > "$h"
   ```
   El hash se calcula en **eval** (`builtins.hashString`), no en runtime: no uses
   `sha256sum`.

Semántica esperada:
- archivo ausente → se siembra;
- existe y hash igual → se respeta (Nexus);
- existe y hash distinto (seed cambió en el repo) → se pisa con el seed y se
  actualiza el hash.

Actualiza el comentario del activation (hoy dice que un `shell.json` real "se
respeta" sin el matiz del hash). No toques `caelestiaCyberpunkScheme`.

## Definition of done

- El activation re-siembra un `shell.json` stale cuando el seed cambia, y
  conserva ediciones cuando el seed no cambió.
- El verify command pasa (prueba funcional con `HOME` temporal).

## Files you own

- `modules/desktop/caelestia.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/**`, `modules/desktop/hyprland*.nix`,
  `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo **system-side**: `lib` es el plano de nixpkgs, no existe `lib.hm.dag`.
  La forma `home.activation.<n> = { after = [ "writeBoundary" ]; before = [ ]; data = …; };`
  es la correcta aquí (igual que el resto del módulo).

## Read first

- `modules/desktop/caelestia.nix` → `let shellConfig`, la línea de
  `shellJsonPath` (~653) y el activation `caelestiaSeedConfig` (~708–721).
- `.workflow/plan.md` → sección "Reproducibilidad entre hosts" y "Wave 10".
- `builtins.hashString` devuelve hex determinista:
  `nix eval --raw --expr 'builtins.hashString "sha256" "x"'`.

## Verify command

```bash
nix flake check --no-build && nix build --no-link --print-out-paths '.#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath' >/dev/null && d="$(nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.home.activation.caelestiaSeedConfig.data')" && rm -rf /tmp/seedtest && mkdir -p /tmp/seedtest/.config/caelestia && printf '{"workspaceIcons":[]}\n' > /tmp/seedtest/.config/caelestia/shell.json && HOME=/tmp/seedtest bash -c "$d" && ! grep -q workspaceIcons /tmp/seedtest/.config/caelestia/shell.json && test -f /tmp/seedtest/.config/caelestia/.shell-seed.sha256 && printf '{"custom":true}\n' > /tmp/seedtest/.config/caelestia/shell.json && HOME=/tmp/seedtest bash -c "$d" && grep -q '"custom":true' /tmp/seedtest/.config/caelestia/shell.json
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit.
- Commit ONLY `modules/desktop/caelestia.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave10-executor-1`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y la semántica final (qué pasa si el seed cambia vs si
  no cambia).
