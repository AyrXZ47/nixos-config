# Brief: Wave 3 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Retirar **todo** el cast por VNC del repo:

1. Borrar `modules/apps/vnc.nix` completo (paquete `wayvnc` + comando
   `cast-tablet`).
2. En `home/default.nix`, quitar la línea `../modules/apps/vnc.nix` del bloque
   `imports`.
3. Verifica que no queden referencias: `cast-tablet`, `wayvnc`, `vnc.nix` en
   `home/`, `modules/`, `hosts/`, `flake.nix`. Los binds de teclado que las
   usaban los quita executor-1 en `modules/desktop/hyprland-home.nix` (no
   toques ese archivo). Si encuentras alguna referencia que NO sea en
   `hyprland-home.nix`, repórtala al planner en vez de inventar.

`modules/apps/miracast.nix` (`gnome-network-displays`) SE QUEDA intacto: es el
método bueno para TVs.

## Definition of done

- `modules/apps/vnc.nix` no existe; `home/default.nix` no lo importa.
- Sin referencias a `cast-tablet`/`wayvnc`/`vnc.nix` fuera de
  `modules/desktop/hyprland-home.nix` (que lo maneja executor-1).
- `gnome-network-displays` sigue en `modules/apps/miracast.nix`.
- El verify command pasa. Solo `modules/apps/vnc.nix` (borrado) y
  `home/default.nix` modificados.

## Files you own

- `modules/apps/vnc.nix` (borrar)
- `home/default.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/**`, `modules/apps/miracast.nix`,
  `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `home/default.nix` es home-side; aquí no hay activations.

## Read first

- `home/default.nix` (bloque `imports`, línea ~18).
- `modules/apps/vnc.nix` (qué se borra y por qué).
- `.workflow/plan.md` → hallazgo de cast y Wave 3 T2.

## Verify command

```bash
nix flake check --no-build && test ! -f modules/apps/vnc.nix && ! grep -q 'vnc.nix' home/default.nix && ! grep -rq 'cast-tablet\|wayvnc' modules/ home/ hosts/ flake.nix && grep -q 'gnome-network-displays' modules/apps/miracast.nix
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `refactor(cast): retirar el cast VNC (wayvnc/cast-tablet)`.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): `git push origin wave3-executor-2` tras el
  commit. Nunca a `main` ni a otra rama.

## Report back

- Diff resumido (incluye el `git rm`), salida del verify, y cualquier
  referencia a cast que hayas encontrado fuera de tu scope.
